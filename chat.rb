# Imports
require 'sinatra'
require 'haml'
require 'json'

class ChatWithFrames < Sinatra::Base
  
  # Server Configuration
  configure do
    set server: 'thin', connections: []
    enable :sessions
  end
  
  # Class variables definition and default assignment
  @@clientsByConnection ||= {}
  @@clientsByName ||= {}
  @@usernames ||= {}
  @@anonymous_counter ||= 0
  @@user_stream_clients ||= []
  
  # Setting up a thread that sends the user list to clients every second
  Thread.new do
    while true do
      sleep 1
      
      user_list = @@clientsByName.keys.sort
      
      @@user_stream_clients.each do |client| 
        client << "data: {#{%Q{"users"}}:#{user_list.to_json}, #{%Q{"num"}}:#{user_list.size} }\n\n" 
      end
      
    end
  end
  
  # Route definition
  get '/' do
    if session['error']
      error = session['error']
      session['error'] = nil
      haml :index, :locals => { :error_message => error }
    else
      haml :index
    end
  end
  
  get '/chat' do
    haml :chat
  end
  
  post '/register-to-chat' do
    username = params[:username]
    if (not @@clientsByName.has_key? username)
      session['user'] = username
      redirect '/chat'
    else
      session['error'] = 'Sorry, the username is already taken.'
      redirect '/'
    end
  end
  
  get '/chat-stream', provides: 'text/event-stream' do
    content_type 'text/event-stream'
    
    if (session['user'] == nil)
      redirect '/'
    else
      username = session['user']
    end
    
    stream :keep_open do |out|
      add_connection(out, username)
      
      out.callback { remove_connection(out, username) }
      out.errback { remove_connection(out, username) }
    end
  end
  
  get '/chat-users', provides: 'text/event-stream' do
    stream :keep_open do |out|
      add_user_stream_client(out)
      
      out.callback { remove_user_stream_client out }
      out.errback { remove_user_stream_client out }
    end
  end
  
  post '/chat' do
    message = params[:message]
    
    if message =~ /\s*\/(\w+)\s+/
      name = $1
      sender = session['user']
      if @@clientsByName.has_key? name
        stream_receiver = @@clientsByName[name]
        stream_sender = @@clientsByName[sender]
        
        stream_receiver << "data: #{sender}: #{message}\n\n"
        stream_sender << "data: #{sender}: #{message}\n\n"
      else #User not found, then broadcast
        broadcast(message, session['user'])
      end
      
    else
      broadcast(message, session['user'])
    end
    "Message Sent" 
  end
  
  get '/*' do
    redirect '/'
  end
  
  private
  def add_connection(stream, username) 
    @@clientsByConnection[stream] = username
    @@clientsByName[username] = stream
  end
  
  def add_user_stream_client(stream)
    @@user_stream_clients += [stream]
  end
  
  def remove_user_stream_client(stream)
    @@user_stream_clients.delete stream
  end
  
  def remove_connection(stream, username)
    @@clientsByConnection.delete stream
    @@clientsByName.delete username
  end
  
  def broadcast(message, sender)
    @@clientsByConnection.each_key { |stream| stream << "data: #{sender}: #{message}\n\n" }
  end
  
  def pop_username_from_list(id)
    username = @@usernames[id]
    @@usernames.delete id
    return username
  end
  
end

ChatWithFrames.run!