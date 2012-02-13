Luca.Collection = Backbone.QueryCollection.extend
  base: 'Luca.Collection'

Luca.Collection._baseParams = {}
Luca.Collection.baseParams = (obj)->
  return Luca.Collection._baseParams = obj if obj

  if _.isFunction( Luca.Collection._baseParams )
    return Luca.Collection._baseParams.call()
  
  if _.isObject( Luca.Collection._baseParams )
    Luca.Collection._baseParams

Luca.Collection._bootstrapped_models = {}

Luca.Collection.bootstrap = (obj)->
  _.extend Luca.Collection._bootstrapped_models, obj

Luca.Collection.cache = (key, models)->
  return Luca.Collection._bootstrapped_models[ key ] = models if models
  Luca.Collection._bootstrapped_models[ key ] || []

_.extend Luca.Collection.prototype,
  initialize: (models, @options={})->
    _.extend @, @options

    if @cached
      @bootstrap_cache_key = if _.isFunction( @cached ) then @cached() else @cached  
    # if we are to register with some global collection management system
    if @registerWith
      @registerAs ||= @cached
      @registerAs = if _.isFunction( @registerAs ) then @registerAs() else @registerAs

      @bind "after:initialize", ()=>
        @register( @registerWith, @registerAs, @)
 
    if _.isArray(@data) and @data.length > 0
      @local = true
    
    @wrapUrl()
     
    Backbone.Collection.prototype.initialize.apply @, [models, @options] 

    @trigger "after:initialize"
  
  wrapUrl: ()->
    if _.isFunction(@url)
      @url = _.wrap @url, (fn)=>
        val = fn.apply @ 
        parts = val.split('?')

        existing_params = _.last(parts) if parts.length > 1

        queryString = @queryString()
        
        if existing_params and val.match(existing_params)
          queryString = queryString.replace( existing_params, '')

        new_val = "#{ val }?#{ queryString }"
        new_val = new_val.replace(/\?$/,'') if new_val.match(/\?$/)

        new_val
    else
      url = @url
      params = @queryString()
      
      @url = _([url,params]).compact().join("?")  

  queryString: ()->
    parts = _( @base_params ||= Luca.Collection.baseParams() ).inject (memo, value, key)=>
      str = "#{ key }=#{ value }"
      memo.push(str)
      memo
    , [] 

    _.uniq(parts).join("&")

  applyFilter: (filter={}, options={auto:true,refresh:true})->
    @applyParams(filter)
    @fetch(refresh:options.refresh) if options.auto
  
  applyParams: (params)->
    @base_params ||= Luca.Collection.baseParams()
    _.extend @base_params, params

  # Collection Manager Registry
  #
  # If this collection is to be registered with some global collection
  # tracker, such as App.collections, then we will register ourselves
  # with this registry, by storing ourselves with a key
  #
  # To automatically register a collection with the registry, instantiate
  # it with the registerWith property, which can either be a reference to
  # the manager itself, or a string in case the manager isn't available
  # at compile time
  register: (collectionManager="", key="", collection)->
    
    throw "Can not register with a collection manager without a key" unless key.length > 1
    throw "Can not register with a collection manager without a valid collection manager" unless collectionManager.length > 1

    if _.isString( collectionManager )
      collectionManager = Luca.util.nestedValue( collectionManager, window )
      
    throw "Could not register with collection manager" unless collectionManager 
    
    if _.isFunction( collectionManager.add )
      return collectionManager.add(key, collection)

    if _.isObject( collect)
      collectionManager[ key ] = collection
    
  bootstrap: ()->
    return unless @bootstrap_cache_key
    @reset @cached_models()

  cached_models: ()->
    Luca.Collection.cache( @bootstrap_cache_key )

  fetch: (options={})->
    @trigger "before:fetch", @

    return @reset(@data) if @local is true
    
    return @bootstrap() if @cached_models().length and not options.refresh
    
    @reset()

    @fetching = true

    url = if _.isFunction(@url) then @url() else @url
    
    return true unless ((url and url.length > 1) or @localStorage)

    try
      Backbone.Collection.prototype.fetch.apply @, arguments
    catch e
      console.log "Error in Collection.fetch", e
      throw e

  ifLoaded: (fn, scope=@)->
    if @models.length > 0 and not @fetching
      fn.apply scope, [@]
      return

    @bind "reset", (collection)=>
      fn.apply scope, [collection]

    unless @fetching
      @fetch()

  parse: (response)-> 
    @fetching = false
    @trigger "after:response"
    models = if @root? then response[ @root ] else response
    
    if @bootstrap_cache_key
      Luca.Collection.cache( @bootstrap_cache_keys, models)

    models
