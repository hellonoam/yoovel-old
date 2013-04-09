class Song
  attr_reader :name, :description, :image, :apps

  def initialize(place_hash)
    @name = "Young Folks"
    @description = "Peter Bjorn And John"
    @image = "/images/generic_image.jpg"

    @apps = []
    @apps << { :rank => 1, :name => "spotify", :icon => "spotify.jpg", :title => "Spotify",
        :sub_title => "listen to #{@name} on Spotify",
        :link => "spotify:track:6M6UoxIPn4NOWW0x7JPRfv" }

    @apps << { :rank => 12, :name => "songkick", :icon => "songkick.jpg", :title => "Songkick",
        :sub_title => "Find concerts on Songkick",
        # TODO(noam): find url scheme if one exists
        :link => "songkick://" }

    @apps << { :rank => 13, :name => "music", :icon => "music.jpg", :title => "Music",
        :sub_title => "You have this song in the music app",
        # TODO(noam): find url scheme if one exists
        :link => "music://" }


    @apps << { :rank => 4, :name => "pandora", :icon => "pandora.jpg", :title => "Pandora",
        :sub_title => "Listen to the #{@name} station",
        :link => "pandorav2:/createStation?song=#{@name.gsub(" ", "+")}&" +
          "artist=#{@description.gsub(" ","+")}" }

    @apps << { :rank => 5, :name => "itunes", :icon => "itunes.jpg", :title => "iTunes",
        :sub_title => "Buy this song on itunes",
        :link => "itmss://itunes.apple.com/us/album/writers-block/id215554129?ign-mpt=uo%3D4#" }

    @apps << { :rank => 6, :name => "last.fm", :icon => "lastfm.jpg", :title => "Last.fm",
        :sub_title => "#{@name} on Last.fm",
        :link => "lastfm://artist/peter+bjorn+and+john" }

    @apps << { :rank => 7, :name => "Youtube", :icon => "youtube.jpg", :title => "Youtube",
        :sub_title => "Watch a youtube clip for #{@name}",
        :link => "http://www.youtube.com/watch?v=OIRE6iw-ws4" }

    @apps.sort! { |a, b| a[:rank] <=> b[:rank] }
  end

end
