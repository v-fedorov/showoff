request = require('request')

class DataHelper
  'fetchDefs': ->
    @fetchStatDefs (error, response, body) =>
      @statDefs = JSON.parse(body)
    @fetchVendorDefs (error, response, body) =>
      @vendorDefs = JSON.parse(body)

  'serializeFromApi': (response) ->
    rarityColor =
      Uncommon: '#f5f5f5'
      Common: '#2f6b3c'
      Rare: '#557f9e'
      Legendary: '#4e3263'
      Exotic: '#ceae32'

    item = response.data.item
    hash = item.itemHash
    itemDefs = response.definitions.items[hash]
    nodes = response.data.talentNodes

    prefix = 'http://www.bungie.net'
    iconSuffix = defData.icon
    itemSuffix = '/en/Armory/Detail?item='+hash

    itemName: itemDefs.itemName
    itemDescription: itemDefs.itemDescription
    itemTypeName: itemDefs.itemTypeName
    rarity: itemDefs.tierTypeName
    color: rarityColor[itemDefs.tierTypeName]
    iconLink: prefix + iconSuffix
    itemLink: prefix + itemSuffix
    primaryStat: item.primaryStat
    stats: item.stats


  'parseItemsForAttachment': (items) ->
    items.map (item) => @parseItemAttachment(item)

  'parseItemAttachment': (item) ->
    hasStats = item.stats
    statFields = if hasStats then @buildStats(item.stats, item.primaryStat) else []

    fallback: item.itemDescription
    title: item.itemName
    title_link: item.itemLink
    color: item.color
    text: item.itemDescription
    thumb_url: item.iconLink
    fields: statFields

  'buildStats': (statsData, primaryData) ->
    defs = @statDefs

    foundStats = statsData.map (stat) ->
      found = defs[stat.statHash]
      return if not found

      title: found.statName
      value: stat.value
      short: true

    primaryFound = primaryData and defs[primaryData.statHash]

    if primaryFound
      primaryStat =
        title: primaryFound.statName
        value: primaryData.value
        short: false

      foundStats.unshift(primaryStat)

    foundStats.filter (x) -> x

  'fetchVendorDefs': (callback) ->
    options =
      method: 'GET'
      url: 'http://destiny.plumbing/raw/mobileWorldContent/en/DestinyStatDefinition.json'
      gzip: true

    request(options, callback)

  'fetchStatDefs': (callback) ->
    options =
      method: 'GET'
      url: 'http://destiny.plumbing/raw/mobileWorldContent/en/DestinyStatDefinition.json'
      gzip: true

    request(options, callback)

module.exports = DataHelper
