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

    prefix = 'http://www.bungie.net'
    iconSuffix = itemDefs.icon
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
    nodes: response.data.talentNodes
    nodeDefs: response.definitions.talentGrids[item.talentGridHash].nodes


  'parseItemsForAttachment': (items) ->
    items.map (item) => @parseItemAttachment(item)

  'parseItemAttachment': (item) ->
    hasStats = item.stats
    statFields = if hasStats then @buildStats(item.stats, item.primaryStat) else []
    filtered = @filterNodes(item.nodes, item.nodeDefs)
    nodeFields = @buildFields(filtered, item.nodeDefs)
    text = @buildText(filtered, item.nodeDefs)
    formattedText = for column, string of text
      string

    fallback: item.itemDescription
    title: item.itemName
    title_link: item.itemLink
    color: item.color
    text: formattedText.join('\n')
    thumb_url: item.iconLink
    fields: nodeFields

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

  #
  'filterNodes': (nodes, nodeDefs) ->
    validNodes = []
    invalid = (node) ->
      node.stateId is "Invalid" or node.hidden is true

    validNodes.push node for node in nodes when not invalid(node)

    orderedNodes = []
    column = 0
    while orderedNodes.length < validNodes.length
      idx = 0
      while idx < validNodes.length
        node = validNodes[idx]
        nodeColumn = nodeDefs[node.nodeIndex].column
        orderedNodes.push(node) if nodeColumn is column
        idx++
      column++
    return orderedNodes

  'buildFields': (nodes, nodeDefs) ->
    displayNodes = nodes.map (node) ->
      step = nodeDefs[node.nodeIndex].steps[node.stepIndex]
      description = step.nodeStepDescription.replace(/(\r\n|\n|\r)/gm," ").replace("  "," ")

      title: step.nodeStepName
      value: description
      short: true

    displayNodes.filter (x) -> x

  'buildText': (nodes, nodeDefs) ->
    getName = (node) ->
      step = nodeDefs[node.nodeIndex].steps[node.stepIndex]
      return step.nodeStepName

    text = {}
    setText = (node) ->
      step = nodeDefs[node.nodeIndex].steps[node.stepIndex]
      column = nodeDefs[node.nodeIndex].column
      text[column] = "" unless text[column]
      text[column]+= "#{step.nodeStepName} "

    setText node for node in nodes
    return text

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
