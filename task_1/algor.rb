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
  def rating_avg(isbn)
    ratings = BookRating.all(:isbn => isbn)
    "Arithmetisches Mittel: #{ratings.collect {|i| i.book_rating }.reduce(:+)/ratings.count.to_f}"
  end

  def rating_median(isbn)
    ratings = BookRating.all(:isbn => isbn, :order => :book_rating)
    n = ratings.count
    if n%2 == 0
      "Median: #{(ratings[n/2-1].book_rating + ratings[n/2].book_rating)/2}"
    else
      "Median: #{ratings[n/2-1].book_rating}"
    end
  end

  def rating_p_quantil(isbn, percent)
    ratings = BookRating.all(:isbn => isbn, :order => :book_rating)
    n = ratings.count
    q = (n * percent)
    if q%1 == 0
      "p-Quantil 25%: #{(ratings[q].book_rating + ratings[q+1].book_rating) / 2}"
    else
      "p-Quantil 25%: #{ratings[q.floor].book_rating}"
    end
  end

  def user_rating_avg(user_id)
    ratings = BookRating.all(:user_id => user_id)
    "Arithmetisches Mittel: #{ratings.collect {|i| i.book_rating }.reduce(:+)/ratings.count.to_f}"
  end

  def user_rating_sx(user_id)
    ratings = BookRating.all(:user_id => user_id)
    "Sx: #{standard_deviation(ratings)}"
  end

  def related_users(user_id)
    isbns = BookRating.all(:user_id => user_id).collect { |i| i.isbn }

    return repository(:default).adapter.select('SELECT "User-ID" FROM book_ratings WHERE "ISBN" IN ? AND "User-ID" != ?
                                                GROUP BY "User-ID" HAVING COUNT("User-ID") >= 7', isbns, user_id)
  end

  def standard_deviation(x)
    n = x.count
    avg = x.collect {|i| i.book_rating }.reduce(:+)/n.to_f
    z = 0
    x.each {|i| z+=(i.book_rating-avg)**2 }
    Math.sqrt( (1/(n-1).to_f) *z)
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

  def spearman(x, y)
    return pearson(spearman_ranks(x), spearman_ranks(y))
  end

  def spearman_ranks(x)
    x.sort!
    puts x.inspect
    y = x.collect{|i| found = []; x.each_index {|e| (x[e]==i) ? found << (e+1) : nil }; i = found.reduce(:+)/found.count.to_f }
    puts y.inspect
    return y
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

  def compare_users(user1_id, user2_id)
    isbns = repository(:default).adapter.select('SELECT "ISBN" FROM book_ratings WHERE "User-ID" IN ?
                                                GROUP BY "ISBN" HAVING COUNT("ISBN") = 2', [user1_id, user2_id])

    x = BookRating.all(:isbn => isbns, :user_id => user1_id).collect{|i| i.book_rating}
    y = BookRating.all(:isbn => isbns, :user_id => user2_id).collect{|i| i.book_rating}

    "<li>Pearson : #{pearson(x, y)}</li>
     <li>Speearman: #{spearman(x, y)}</li>
     <li>Cosine Similarity: #{cosine_similarity(x, y)}</li>"
  end

end
