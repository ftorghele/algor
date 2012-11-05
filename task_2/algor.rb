require 'rubygems'
require 'data_mapper'
require 'dm-types'
require 'csv'


class BookRating
  include DataMapper::Resource

  property :user_id, Serial, :field => "User-ID", :key => true
  property :isbn, String, :field => "ISBN", :key => true
  property :book_rating, Integer, :field => "Book-Rating"
end

class Book
  include DataMapper::Resource

  property :isbn, String, :field => "ISBN", :key => true
#  property :title, String, :field => "Book-Title"
#  property :author, String, :field => "Book-Author"
#  property :year, Integer, :field => "Year-Of-Publication"
#  property :publisher, String, :field => "Publisher"
#  property :image_s, String, :field => "Image-URL-S"
#  property :image_m, String, :field => "Image-URL-M"
#  property :image_l, String, :field => "Image-URL-L"
end

class User 
  include DataMapper::Resource

  property :user_id, Serial, :field => "User-ID", :key => true
  property :location, String, :field => "Location"
  property :age, Integer, :field => "Age"

end


class Main 
  @@config = YAML.load_file("./config.yml") rescue nil || {}
  DataMapper.setup(:default, "mysql://#{@@config["db"]["user"]}:#{@@config["db"]["pwd"]}@localhost/#{@@config["db"]["name"]}")

  # Identifizieren Sie die 50 Benutzer mit den meisten Bewertungen (≠ 0).
  user_ids = repository(:default).adapter.select('SELECT COUNT("User-ID") as count, "User-ID" FROM book_ratings
                                                  WHERE "Book-Rating" != 0
                                                  GROUP BY "User-ID"
                                                  ORDER BY count DESC LIMIT 5').collect{|i| i.user_id}


  def self.random_rating(size, relative_frequency_boundary)
    r = Random.new
    random_number = r.rand(1..size)

    case random_number
      when 1..relative_frequency_boundary[1]
        return 1
      when relative_frequency_boundary[1]..relative_frequency_boundary[2]
        return 2
      when relative_frequency_boundary[2]..relative_frequency_boundary[3]
        return 3
      when relative_frequency_boundary[3]..relative_frequency_boundary[4]
        return 4
      when relative_frequency_boundary[4]..relative_frequency_boundary[5]
        return 5
      when relative_frequency_boundary[5]..relative_frequency_boundary[6]
        return 6
      when relative_frequency_boundary[6]..relative_frequency_boundary[7]
        return 7
      when relative_frequency_boundary[7]..relative_frequency_boundary[8]
        return 8
      when relative_frequency_boundary[8]..relative_frequency_boundary[9]
        return 9
      when relative_frequency_boundary[9]..size
        return 10
      else
        raise 'Fail'
    end
  end

  def self.pearson(x,y)
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

  ###########################################################

  users_book_ratings={}

  CSV.open("ratings_matrix.csv", "wb") do |csv|

    user_ids.each do |user_id|
      
      # Berechnung der entsprechenden relativen Häufigkeit
      relative_frequency = []
      relative_frequency[0] = BookRating.all(:user_id => user_id, :book_rating.gt => 0).count #all ratings by user
      (1..10).each do |i|
        relative_frequency[i] = BookRating.all(:user_id => user_id, :book_rating => i).count
      end
     # relative_frequencies[user_id] = relative_frequency

      book_ratings = []

      relative_frequency_boundary = []
      relative_frequency_boundary[1] = relative_frequency[1]
      relative_frequency_boundary[2] = relative_frequency[1..2].reduce(:+)
      relative_frequency_boundary[3] = relative_frequency[1..3].reduce(:+)
      relative_frequency_boundary[4] = relative_frequency[1..4].reduce(:+)
      relative_frequency_boundary[5] = relative_frequency[1..5].reduce(:+)
      relative_frequency_boundary[6] = relative_frequency[1..6].reduce(:+)
      relative_frequency_boundary[7] = relative_frequency[1..7].reduce(:+)
      relative_frequency_boundary[8] = relative_frequency[1..8].reduce(:+)
      relative_frequency_boundary[9] = relative_frequency[1..9].reduce(:+)


      Book.all(:limit => 1000).each do |book|
        br = BookRating.first(:isbn => book.isbn, :user_id => user_id)
        book_ratings << (br.nil? ? random_rating(relative_frequency[0], relative_frequency_boundary) : ( (br.book_rating == 0) ? random_rating(relative_frequency[0], relative_frequency_boundary) : br.book_rating)  )
      end
      csv << [user_id]
      csv << book_ratings
      users_book_ratings[user_id] = book_ratings
    end
  end


  max = 0;
  u1_id = nil;
  u2_id = nil;

  users = User.all(:user_id => user_ids)

  CSV.open("pearson_matrix.csv", "w") do |csv|
    all_pearson = {}
    users.each do |user_1|
      pearson_m = []
      users.each do |user_2|
        
        x = users_book_ratings[user_1.user_id]
        y = users_book_ratings[user_2.user_id]
        p = Main.pearson(x, y)
        pearson_m << p
        if (user_1.user_id != user_2.user_id && p > max)
          max = p 
          u2_id = user_2.user_id
          u1_id = user_1.user_id
        end
      end
      csv << pearson_m
      all_pearson[user_1.user_id] = pearson_m
    end
    csv << ["\n"]
  end

  CSV.open("pearson_result.csv", "w") do |csv|
    csv << [u1_id]
    csv << [u2_id]
    csv << [max]
  end

  puts u1_id
  puts u2_id
  puts max
end

