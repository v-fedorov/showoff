require('dotenv').load()
Deferred = require('promise.coffee').Deferred
DataHelper = require('./bungie-data-helper.coffee')

dataHelper = new DataHelper

module.exports = (robot) ->
  dataHelper.fetchDefs()

  # executes when any text is directed at the bot
  robot.respond /(.*)/i, (res) ->
    input = res.match[1].split ' '

    # defaults to slack username
    if input.length is 2
      input.unshift(res.message.user.name)

    xbox = ['xbox', 'xb1', 'xbox1', 'xboxone', 'xbox360', 'xb360', 'xbone']
    playstation = ['playstation', 'ps', 'ps3', 'ps4', 'playstation3', 'playstation4']
    sanitized = input[1].toLowerCase().replace(" ", "")
    if sanitized in xbox
      input[1] = 'xbox'
    else if sanitized in playstation
      input[1] = 'playstation'
    else
      robot.send {room: res.message.user.name, "unfurl_media": false}, "Something went wrong... Read more about using the bot here:\nhttps://github.com/phillipspc/showoff/blob/master/README.md"
      return

    unless input[2].toLowerCase() in ['primary', 'special', 'secondary', 'heavy']
      robot.send {room: res.message.user.name, "unfurl_media": false}, "Please use 'primary', 'special', or 'heavy' for the weapon slot. Read more about using the bot here:\nhttps://github.com/phillipspc/showoff/blob/master/README.md"
      return

    data = generateInputHash(input)

    getPlayerId(res, data.membershipType, data.displayName, robot).then (playerId) ->
      getCharacterId(res, data.membershipType, playerId).then (characterId) ->
        getItemIdFromSummary(res, data.membershipType, playerId, characterId, data.weaponSlot).then (itemInstanceId) ->
          getItemDetails(res, data.membershipType, playerId, characterId, itemInstanceId).then (item) ->
            parsedItem = dataHelper.parseItemAttachment(item)

            payload =
              message: res.message
              attachments: parsedItem

            robot.emit 'slack-attachment', payload


# takes an input (array) and returns a hash
generateInputHash = (input) ->
  network = if input[1] is 'xbox' then '1' else '2'
  name = if network is '1' then input[0].split("_").join(" ") else input[0]
  if input[2] is 'primary'
    wpnSlot = 1
  else if input[2] in ['special', 'secondary']
    wpnSlot = 2
  else
    wpnSlot = 3

  return {
    membershipType: network,
    displayName: name,
    weaponSlot: wpnSlot
  }


# Gets general player information from a players gamertag
getPlayerId = (res, membershipType, displayName, robot) ->
  deferred = new Deferred()
  endpoint = "SearchDestinyPlayer/#{membershipType}/#{displayName}"
  networkName = if membershipType is '1' then 'xbox' else 'playstation'

  makeRequest res, endpoint, (response) ->
    foundData = response[0]

    if !foundData
      robot.send {room: res.message.user.name}, "Could not find guardian with name: #{displayName} on #{networkName}"
      deferred.reject()
      return

    playerId = foundData.membershipId
    deferred.resolve(playerId)

  deferred.promise

# Gets characterId for last played character
getCharacterId = (bot, membershipType, playerId) ->
  deferred = new Deferred()
  endpoint = "#{membershipType}/Account/#{playerId}"

  makeRequest bot, endpoint, (response) ->
    data = response.data
    character = data.characters[0]

    characterId = character.characterBase.characterId
    deferred.resolve(characterId)

  deferred.promise

# Gets itemInstanceId from Inventory Summary based on weaponSlot
getItemIdFromSummary = (bot, membershipType, playerId, characterId, weaponSlot) ->
  deferred = new Deferred()
  endpoint = "#{membershipType}/Account/#{playerId}/Character/#{characterId}/Inventory/Summary"

  makeRequest bot, endpoint, (response) ->
    data = response.data
    itemInstanceId = data.items[weaponSlot].itemId
    deferred.resolve(itemInstanceId)

  deferred.promise

# returns item details
getItemDetails = (bot, membershipType, playerId, characterId, itemInstanceId) ->
  deferred = new Deferred()
  endpoint = "#{membershipType}/Account/#{playerId}/Character/#{characterId}/Inventory/#{itemInstanceId}"
  params = 'definitions=true'

  callback = (response) ->
    item = dataHelper.serializeFromApi(response)

    deferred.resolve(item)

  makeRequest(bot, endpoint, callback, params)
  deferred.promise

# Sends GET request from an endpoint, needs a success callback
makeRequest = (bot, endpoint, callback, params) ->
  BUNGIE_API_KEY = process.env.BUNGIE_API_KEY
  baseUrl = 'https://www.bungie.net/Platform/Destiny/'
  trailing = '/'
  queryParams = if params then '?'+params else ''
  url = baseUrl+endpoint+trailing+queryParams

  bot.http(url)
    .header('X-API-Key', BUNGIE_API_KEY)
    .get() (err, response, body) ->
      object = JSON.parse(body)
      callback(object.Response)
