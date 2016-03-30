request = require('request')

class DataHelper
  'fetchDefs': ->
    @fetchStatDefs (error, response, body) =>
      @statDefs = JSON.parse(body)
    @fetchVendorDefs (error, response, body) =>
      @vendorDefs = JSON.parse(body)

  'serializeFromApi': (response) ->
    damageColor =
      Kinetic: '#d9d9d9'
      Arc: '#80b3ff'
      Solar: '#e68a00'
      Void: '#400080'

    item = response.data.item
    hash = item.itemHash
    itemDefs = response.definitions.items[hash]
    damageTypeName = response.definitions.damageTypes[item.damageTypeHash].damageTypeName

    prefix = 'http://www.bungie.net'
    iconSuffix = itemDefs.icon
    itemSuffix = '/en/Armory/Detail?item='+hash

    itemName: itemDefs.itemName
    itemDescription: itemDefs.itemDescription
    itemTypeName: itemDefs.itemTypeName
    color: damageColor[damageTypeName] or '#d9d9d9'
    iconLink: prefix + iconSuffix
    itemLink: prefix + itemSuffix
    nodes: response.data.talentNodes
    nodeDefs: response.definitions.talentGrids[item.talentGridHash].nodes
    damageType: damageTypeName

  'parseItemsForAttachment': (items) ->
    items.map (item) => @parseItemAttachment(item)

  'parseItemAttachment': (item) ->
    name = "#{item.itemName}"
    name+= " [#{item.damageType}]" unless item.damageType is "Kinetic"
    filtered = @filterNodes(item.nodes, item.nodeDefs)
    textHash = @buildText(filtered, item.nodeDefs)
    formattedText = for column, string of textHash
      # removes trailing " | " from each line
      string.slice(0, -3)

    fallback: item.itemDescription
    title: name
    title_link: item.itemLink
    color: item.color
    text: formattedText.join('\n')
    mrkdwn_in: ["text"]
    thumb_url: item.iconLink

  # removes invalid nodes, orders according to column attribute
  'filterNodes': (nodes, nodeDefs) ->
    validNodes = []
    invalid = (node) ->
      name = nodeDefs[node.nodeIndex].steps[node.stepIndex].nodeStepName
      skip = ["Upgrade Damage", "Void Damage", "Solar Damage", "Arc Damage", "Kinetic Damage"]
      node.stateId is "Invalid" or node.hidden is true or name in skip

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

  # creates fields for perks and their descriptions
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
      name = step.nodeStepName
      if node.isActivated
        name = '_*' + step.nodeStepName + '*_'
      text[column] = "" unless text[column]
      text[column]+= name + " | "

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
