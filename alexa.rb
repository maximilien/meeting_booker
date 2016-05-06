require 'sinatra/base'
require 'alexa_rubykit'
require 'json'
require './gcalendar'
require 'active_support/all'

class AlexaApp < Sinatra::Base
	post '/find_me' do
	
	  	booker = MeetingBooker.new
	  	rooms = booker.find_rooms(1.hour, DateTime.now + 5.hours)
	  	alexa_response = rooms.empty? ? 
	  		"I am sorry, there are no free rooms available at this time." :
	  		"#{rooms.first[:name]} is available."

	  	response = AlexaRubykit::Response.new
		response.add_speech(alexa_response)
		resp = response.build_response
		body resp
	end

	get '/oauth2callback' do
		puts request.inspect		
		status 200
		body '<html><h1>MeetingBooker registered you!</h1></html>'
	end		
end