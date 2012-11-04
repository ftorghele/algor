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
                                                  ORDER BY count DESC LIMIT 50').collect{|i| i.user_id}
  puts user_ids.inspect

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

end

