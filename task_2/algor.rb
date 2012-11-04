require 'rubygems'
require 'data_mapper'
require 'dm-types'

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

class Main
  @@config = YAML.load_file("./config.yml") rescue nil || {}
  DataMapper.setup(:default, "mysql://#{@@config["db"]["user"]}:#{@@config["db"]["pwd"]}@localhost/#{@@config["db"]["name"]}")

  # Identifizieren Sie die 50 Benutzer mit den meisten Bewertungen (≠ 0).
  user_ids = repository(:default).adapter.select('SELECT COUNT("User-ID") as count, "User-ID" FROM book_ratings
                                                  WHERE "Book-Rating" != 0
                                                  GROUP BY "User-ID"
                                                  ORDER BY count DESC LIMIT 1').collect{|i| i.user_id}

  def self.random_rating(relative_frequency)
    r = Random.new
    random_number = r.rand(1...relative_frequency[0])

    case random_number
      when 1..relative_frequency[1]
        return 1
      when relative_frequency[1]..(relative_frequency[1..2].reduce(:+))
        return 2
      when (relative_frequency[1..2].reduce(:+))..(relative_frequency[1..3].reduce(:+))
        return 3
      when (relative_frequency[1..3].reduce(:+))..(relative_frequency[1..4].reduce(:+))
        return 4
      when (relative_frequency[1..4].reduce(:+))..(relative_frequency[1..5].reduce(:+))
        return 5
      when (relative_frequency[1..5].reduce(:+))..(relative_frequency[1..6].reduce(:+))
        return 6
      when (relative_frequency[1..6].reduce(:+))..(relative_frequency[1..7].reduce(:+))
        return 7
      when (relative_frequency[1..7].reduce(:+))..(relative_frequency[1..8].reduce(:+))
        return 8
      when (relative_frequency[1..8].reduce(:+))..(relative_frequency[1..9].reduce(:+))
        return 9
      when (relative_frequency[1..9].reduce(:+))..(relative_frequency[1..10].reduce(:+))
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

  relative_frequencies={}
  user_ratings={}

  user_ids.each do |user_id|
    user_ratings[user_id] =  BookRating.all(:user_id => user_id, :limit => 100)

    # Berechnung der entsprechenden relativen Häufigkeit
    relative_frequency = []
    relative_frequency[0] = BookRating.all(:user_id => user_id, :book_rating.gt => 0).count #all ratings by user
    (1..10).each do |i|
      relative_frequency[i] = BookRating.all(:user_id => user_id, :book_rating => i).count
    end
    relative_frequencies[user_id] = relative_frequency

    # 0 Werte auffüllen
    user_ratings[user_id].each do |rating|
      if rating.book_rating == 0
        rating.book_rating = random_rating(relative_frequency)
      end
    end

    puts user_ratings.inspect

  end

end

