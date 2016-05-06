require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'active_support/all'
require 'fileutils'

OOB_URI = 'https://5b80cc6b.ngrok.io/oauth2callback'
APPLICATION_NAME = 'MeetingBooker'
CLIENT_SECRETS_PATH = 'client_secret.json'
CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                             "calendar-ruby-quickstart.yaml")
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

class MeetingBooker
  def get_freebusy(calendars, service, start_time, duration)
    request = Google::Apis::CalendarV3::FreeBusyRequest.new(
      time_min: start_time,
      time_max: start_time + duration,
      items: calendars.map{ |m| {id: m.id} }
      )
    result = service.query_freebusy(request) 
    return result
  end

  def pivotal_calendars(service)
    calendars = Array.new
    page_token = nil
    begin
      result = service.list_calendar_lists(page_token: page_token)
      result.items.each do |e|
        next if e.id !~ /pivotal.io/
        calendars << e
     end
      if result.next_page_token != page_token
        page_token = result.next_page_token
      else
        page_token = nil
      end
    end while !page_token.nil?
    calendars
  end

  def authorize
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(
      client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(
        base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " +
           "resulting code after authorization"
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI)
    end
    credentials
  end

  def init_google_calendarv3
    service = Google::Apis::CalendarV3::CalendarService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize
    service
  end

  def get_free_rooms(freebusy, calendars)
    free_rooms = Array.new
    freebusy.calendars.each do |k, c|
      summary = calendars.select {|cc| cc.id == k}.first.summary
      if c.busy.first.nil?
        summary =~ /(.+) - (\w+) \((.+)\) (.+) (\w+)/
        free_rooms << {
                        location: $1,
                        name: $2,
                        capacity: $3,
                        phone: $4,
                        extension: $5
                       }
      end
    end
    free_rooms
  end

  def find_rooms duration = 1.hours, start_time = DateTime.now
    service = init_google_calendarv3
    calendars = pivotal_calendars(service)
    freebusy = get_freebusy(calendars, service, start_time, duration)
    free_rooms = get_free_rooms(freebusy, calendars)
  end
end
