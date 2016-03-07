require('dotenv').load()
Deferred = require('promise.coffee').Deferred
DataHelper = require('./bungie-data-helper.coffee')

dataHelper = new DataHelper

module.exports = (robot) ->
  dataHelper.fetchDefs()

  # executes when any text is directed at the bot
  robot.respond /(.*)/i, (res) ->
    input = res.match[1].split ' '
    showDetails = false

    # default to slack username if only 2 inputs
    if input.length is 2
      input.unshift(res.message.user.name)

    # some validations
    unless input[1].toLowerCase() in ['xbox', 'playstation']
      res.reply "Please use 'xbox' or 'playstation' as your network."
      return

    unless input[2].indexOf('-') is -1
      idx = input[2].indexOf('-')
      modifier = input[2].slice(idx)
      input[2] = input[2].slice(0, idx)
      showDetails = true if modifier is "-details"
    unless input[2].toLowerCase() in ['primary', 'special', 'heavy']
      res.reply "Please use 'primary', 'special', or 'heavy' for the weapon slot."
      return

    data = generateInputHash(input)

    getPlayerId(res, data.membershipType, data.displayName).then (playerId) ->
      getCharacterId(res, data.membershipType, playerId).then (characterId) ->
        getItemIdFromSummary(res, data.membershipType, playerId, characterId, data.weaponSlot).then (itemInstanceId) ->
          getItemDetails(res, data.membershipType, playerId, characterId, itemInstanceId).then (item) ->
            parsedItem = dataHelper.parseItemAttachment(item, showDetails)

            payload =
              message: res.message
              attachments: parsedItem

            robot.emit 'slack-attachment', payload


# takes an input (array) and returns a hash
generateInputHash = (input) ->
  network = if input[1] is 'xbox' then '1' else '2'
  name = if network is '1' then input[0].replace("_", " ") else input[0]
  if input[2] is 'primary'
    wpnSlot = 1
  else if input[2] is 'special'
    wpnSlot = 2
  else
    wpnSlot = 3

  return {
    membershipType: network,
    displayName: name,
    weaponSlot: wpnSlot
  }


# Gets general player information from a players gamertag
getPlayerId = (bot, membershipType, displayName) ->
  deferred = new Deferred()
  endpoint = "SearchDestinyPlayer/#{membershipType}/#{displayName}"
  networkName = if membershipType is '1' then 'xbox' else 'playstation'

  makeRequest bot, endpoint, (response) ->
    foundData = response[0]

    if !foundData
      bot.send "Could not find guardian with name: #{displayName} on #{networkName}"
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
