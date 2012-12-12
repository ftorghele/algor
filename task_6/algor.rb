require 'rubygems'
require 'sinatra'
require 'haml'
require 'data_mapper'
require 'dm-types'
require 'matrix'

configure do
  @@config = YAML.load_file("./config.yml") rescue nil || {}
end

DataMapper.setup(:default, "mysql://#{@@config["db"]["user"]}:#{@@config["db"]["pwd"]}@localhost/#{@@config["db"]["name"]}")
#DataMapper.auto_upgrade!

class BookRating
  include DataMapper::Resource

  property :user_id, Serial, :field => "User-ID", :key => true
  property :isbn, String, :field => "ISBN", :key => true
  property :book_rating, Integer, :field => "Book-Rating"
end

class User
  include DataMapper::Resource

  property :user_id, Serial, :field => "User-ID", :key => true
  property :location, String, :field => "Location"
  property :age, Integer, :field => "Age"
end

get '/' do
  haml :output, :layout => :'layouts/application'
end

helpers do

  def related_users(user_id)
    isbns = BookRating.all(:user_id => user_id).collect { |i| i.isbn }

    return repository(:default).adapter.select('SELECT "User-ID" FROM book_ratings WHERE "ISBN" IN ? AND "User-ID" != ?
                                                GROUP BY "User-ID" HAVING COUNT("User-ID") >= 7', isbns, user_id)
  end

  def pearson(x,y)
    n=x.length

    sumx=x.inject(0) {|r,i| r + i}
    sumy=y.inject(0) {|r,i| r + i}

    sumxSq=x.inject(0) {|r,i| r + i**2}
    sumySq=y.inject(0) {|r,i| r + i**2}

    prods=[]; x.each_with_index{|this_x,i| prods << this_x*y[i]}
    pSum=prods.inject(0){|r,i| r + i}

    # Calculate Pearson score
    num=pSum-(sumx*sumy/n)
    den=((sumxSq-(sumx**2)/n)*(sumySq-(sumy**2)/n))**0.5
    if den==0
      return 0
    end
    r=num/den
    return r
  end

  def get_top_user_ids
     repository(:default).adapter.select('SELECT COUNT("User-ID") as count, "User-ID" FROM book_ratings
                                                  WHERE "Book-Rating" != 0
                                                  GROUP BY "User-ID"
                                                  ORDER BY count DESC LIMIT 10').collect{|i| i.user_id}
  end

  def cosine_similarity(x, y)
    x_vector = Vector.[](*x)
    y_vector = Vector.[](*y)
    inner_p = x_vector.inner_product y_vector
    if inner_p==0
      return 0
    end
    return inner_p / (x_vector.r * y_vector.r)
  end

  def most_similar_users

    user_ids = get_top_user_ids
    top_user = user_ids[0]
    user_ids.each do |user|
      unless top_user == user 
        isbns = repository(:default).adapter.select('SELECT "ISBN" FROM book_ratings WHERE "User-ID" IN ?
                                                GROUP BY "ISBN" HAVING COUNT("ISBN") = 2', [top_user, user])

        x = BookRating.all(:isbn => isbns, :user_id => top_user).collect{|i| i.book_rating}
        y = BookRating.all(:isbn => isbns, :user_id => user).collect{|i| i.book_rating}
      end
    end
  end

  def rmea original, test
    puts original.inspect
    puts test.inspect
    n = original.length-1
    result = 0.0

    (0..n).each do |index|
      result = result + ( (original[index]-test[index])**2 )
    end
    Math.sqrt(result)
  end

  def simple_copy
    user1 = 11676
    user2 = 248718

    user1_original = []
    user1_test = []

    isbns = repository(:default).adapter.select('SELECT "ISBN" FROM book_ratings WHERE "User-ID" IN ?
                                                GROUP BY "ISBN" HAVING COUNT("ISBN") = 2', [user1, user2])

    count = 0
    isbns.each do |isbn|
      x = BookRating.all(:isbn => isbn, :user_id => user1).collect{|i| i.book_rating}.first
      y = BookRating.all(:isbn => isbn, :user_id => user2).collect{|i| i.book_rating}.first
      
      user1_original << x

      if count % 8 == 0
        user1_test << y
      else
         user1_test << x
      end
      count = count + 1
    end
    rm = rmea(user1_test, user1_original)

    puts "RMEA simple_copy: #{rm}"    
    puts "____________________________________"
  end


  def weighted_copy
    user1 = 11676
    user2 = 248718

    user1_original = []
    user1_test = []

    isbns = repository(:default).adapter.select('SELECT "ISBN" FROM book_ratings WHERE "User-ID" IN ?
                                                GROUP BY "ISBN" HAVING COUNT("ISBN") = 2', [user1, user2])

    count = 0

    user1avg = BookRating.all(:isbn => isbns, :user_id => user1).collect{|i| i.book_rating}.reduce(:+) / isbns.length
    user2avg = BookRating.all(:isbn => isbns, :user_id => user2).collect{|i| i.book_rating}.reduce(:+) / isbns.length

    isbns.each do |isbn|
      x = BookRating.all(:isbn => isbn, :user_id => user1).collect{|i| i.book_rating}.first
      y = BookRating.all(:isbn => isbn, :user_id => user2).collect{|i| i.book_rating}.first
      user1_original << x

      if count % 8 == 0
        user1_test << ((user1avg<user2avg) ? ((y==0) ? y : y-1) : ((y==10) ? y : y+1))
      else
         user1_test << x
      end
      count = count + 1
    end

    rm = rmea(user1_test, user1_original)

    puts "RMEA weighted_copy: #{rm}"
    puts "____________________________________"
  end
end

