require 'sinatra/base'
require 'alexa_rubykit'
require 'json'
require './gcalendar'
require 'active_support/all'
require 'time'

DEFAULT_TIME = 1

class AlexaApp < Sinatra::Base
	post '/find_me' do
		alexa_request = JSON.parse(request.body.read)
		start_interval, length = parse_durations(alexa_request)
	
		time = DEFAULT_TIME
	  	booker = MeetingBooker.new
	  	rooms = booker.find_rooms(length, start_interval)
	  	human_length, human_length_name = humanize_length(length)
	  	alexa_response = rooms.empty? ? 
	  		"I am sorry, there are no free rooms available at this time." :
	  		"#{rooms.sample[:name]} is available for #{human_length} #{human_length_name} starting at #{start_interval.strftime('%I:%M%p')}."

	  	response = AlexaRubykit::Response.new
		response.add_speech(alexa_response)
		resp = response.build_response
		body resp
	end

	get '/oauth2callback' do
		status 200
		body '<html><h1>MeetingBooker registered you!</h1></html>'
	end		

	def humanize_length(length)
		return [1, "minute"] if length == 60
		return [length / 60, "minutes"] if length < 3600
		return [length / 3600, "hours"] if length > 3600
		return [1, "hour"] if length == 3600
	end

	def parse_durations(alexa_object)
		start_interval = parse_duration(alexa_object["request"]["intent"]["slots"]["StartTime"], 0) 
		length = parse_duration(alexa_object["request"]["intent"]["slots"]["Length"], DEFAULT_TIME)		

		start_at  = parse_time(alexa_object["request"]["intent"]["slots"]["StartAt"], 0)
		end_at  = parse_time(alexa_object["request"]["intent"]["slots"]["EndAt"], 0)

		return [DateTime.now + start_interval, length] if start_interval.present? && length.present?
		return [DateTime.now + start_interval, DEFAULT_TIME.hour] if start_interval.present?
		return [start_at, length] if start_at.present? && length.present?
		return [start_at, DEFAULT_TIME.hour] if start_at.present?
		return [start_at, end_at - start_at] if start_at.present? && end_at.present?
		return [DateTime.now, DEFAULT_TIME.hour]
	end

	def parse_time(alexa_object, default)
		val = alexa_object["value"]
		return Time.parse(val).to_datetime if val.present?
		return nil
	end

	def parse_duration(alexa_object, default)
		val = alexa_object["value"]
		return nil if val.nil? 
		
		val =~ /PT(\d+)(M|H)/
		case $2
		when 'M', 'm'
			return $1.to_i.minutes
		when 'H', 'h'
			return $1.to_i.hours
		else
			return default.hours 
		end
	end
end