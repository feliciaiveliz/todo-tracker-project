require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

configure do 
  set :erb, :escape_html => true
end

helpers do 
  def list_complete?(list) 
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
    
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, index|
      if todo[:completed]
        complete_todos[todo] = index
      else
        incomplete_todos[todo] = index
      end
    end

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET   /lists      -> view all lists
# GET   /lists/new  -> new list form
# POST  /lists      -> create a new list
# GET   /lists/1    -> view a single list
# GET   /users
# GET   /users/1

# view list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return il if name is valid.
def list_name_error(name)
  if !(1..100).cover? name.size
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'The list name must be unique.'
  end
end

def todo_error(name)
  if !(1..100).cover? name.size
    'The todo name must be between 1 and 100 characters.'
  end
end

def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = list_name_error(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The '#{list_name}' list has been created!"
    redirect '/lists'
  end
end

# View a single todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end
 
# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = list_name_error(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list name has been changed to #{list_name}!"
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = todo_error(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list

post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].delete_at todo_id
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# Update status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i 
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end 

  