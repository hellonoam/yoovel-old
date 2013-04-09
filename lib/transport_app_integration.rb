class TransportAppIntegration

  def public_model
    @description = "" if @description.nil?
    hash = { :name => @name, :price => @price.to_s, :links => @links, :description => @description,
      :appIconName => @app_icon_name, :duration => @duration.to_s, :rank => @rank.to_i }
    @timer ? hash.merge({ :timer => @timer, :seconds => @seconds.to_i }) : hash
  end

end