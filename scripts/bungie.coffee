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
      res.send "Fetching stats for #{data.displayName}'s #{input[2]} weapon..."
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
  input[0].replace("_", " ") if network is '1'
  if input[2] is 'primary'
    wpnSlot = 1
  else if input[2] is 'special'
    wpnSlot = 2
  else
    wpnSlot = 3

  return {
    membershipType: network,
    displayName: input[0],
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

# Gets Inventory of last played character
# getCharacterInventory = (bot, membershipType, playerId, characterId) ->
#   deferred = new Deferred()
#   endpoint = "#{membershipType}/Account/#{playerId}/Character/#{characterId}/Inventory"
#   params = 'definitions=true'
#
#   callback = (response) ->
#     definitions = response.definitions.items
#     equippable = response.data.buckets.Equippable
#
#     validItems = equippable.map (x) ->
#       x.items.filter (item) ->
#         item.isEquipped and item.primaryStat
#
#     itemsData = [].concat validItems...
#
#     items = itemsData.map (item) -> dataHelper.serializeFromApi(item, definitions)
#
#     deferred.resolve(items)
#
#   makeRequest(bot, endpoint, callback, params)
#   deferred.promise

# Gets genral information about last played character
# getLastCharacter = (bot, playerId) ->
#   deferred = new Deferred()
#   endpoint = '/1/Account/'+playerId
#   genderTypes = ['Male', 'Female', 'Unknown']
#   raceTypes = ['Human', 'Awoken', 'Exo', 'Unknown']
#   classTypes = ['Titan', 'Hunter', 'Warlock', 'Unknown']
#
#   makeRequest bot, endpoint, (response) ->
#     data = response.data
#     chars = data.characters
#     recentChar = chars[0]
#     charData = recentChar.characterBase
#     levelData = recentChar.levelProgression
#
#     level = levelData.level
#     lightLevel = charData.powerLevel
#     gender = genderTypes[charData.genderType]
#     charClass = classTypes[charData.classType]
#
#     phrase = 'level '+level+' '+gender+' '+charClass+', with a light level of: '+lightLevel
#     deferred.resolve(phrase)
#
#   deferred.promise

# Gets a players vendors
# getXurInventory = (bot) ->
#   deferred = new Deferred()
#   endpoint = 'Advisors/Xur'
#   params = 'definitions=true'
#   callback = (response) ->
#     deferred.resolve(response)
#
#   makeRequest(bot, endpoint, callback, params)
#   deferred.promise

# Sends GET request from an endpoint, needs a success callback
makeRequest = (bot, endpoint, callback, params) ->
  BUNGIE_API_KEY = process.env.BUNGIE_API_KEY or 'a264906602d04445b68c87edd11f87f8'
  baseUrl = 'https://www.bungie.net/Platform/Destiny/'
  trailing = '/'
  queryParams = if params then '?'+params else ''
  url = baseUrl+endpoint+trailing+queryParams

  bot.http(url)
    .header('X-API-Key', BUNGIE_API_KEY)
    .get() (err, response, body) ->
      object = JSON.parse(body)
      callback(object.Response)
