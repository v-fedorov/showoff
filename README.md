# Showoff

Showoff is a slack bot based on the [hubot](https://hubot.github.com/) framework, designed to make it easy for users to show off their Destiny weapons in slack. The goal is to enable users to share weapon information with as few inputs as possible.  
This project was based heavily off of [slack-destiny-bot](https://github.com/cprater/slack-destiny-bot) which served as an outstanding basis for me to implement my own functionality. I also recommend checking out that repo for instructions on setting up your own copy of the bot.

### Usage

Showoff only requires 3 inputs, directed at the bot (order does matter):  
* XBL/PSN gamertag
* console network ("xbox" or "playstation")
* weapon slot ("primary", "special", "heavy").  

The standard usage looks like this:  
>@bot-name MyGamertag xbox primary  

with a response looking like:  
![image](https://cloud.githubusercontent.com/assets/11082871/13578078/cebbf29e-e463-11e5-8e66-9971eb844c4f.png)  
Showoff automatically looks at **your most recently played character** when grabbing the weapon data.  

### Advanced Options
If your slack **username** (not first/last name) is the same as your gamertag, you can omit this entirely.  
>@bot-name xbox special

### Caveats
* Xbox users must use an underscore ( _ ) for any spaces in their gamertags.
* As stated above, Showoff automatically looks at your most recently played character. This was ultimately an intentional decision to limit the number of inputs needed and simplify using the bot.
* If you've recently equipped a new weapon, the bot may fail to retrieve the info properly. For best results, wait 10-15 seconds before using the bot.
