#!/usr/bin/env io

Regex

Gio := Object clone do(
  port := 6667
  socket := Socket clone

  connect := method(nick, server, channelString,
    self nick := nick
    self channels := channelString split
    socket setHost(server) setPort(port) connect
    socket lnStreamWrite("USER #{nick} #{nick} #{nick} :Gitarion (Was Jim)" interpolate)
    socket lnStreamWrite("NICK #{nick}" interpolate)
    channels foreach(c, socket lnStreamWrite("JOIN #" .. c))
    socket streamReadNextChunk
    socket readBuffer empty

    parseIncomming
  )

  parseIncomming := method(
    while(socket isOpen,
      socket streamReadNextChunk

      if (socket readBuffer size != 0,
        preline := socket readBuffer
        preline split("\r\n") foreach(l,
          reply := parseLine(l)
          if(reply, send(reply))
        )
      )

      socket readBuffer empty
    )
  )

  parseLine := method(line,
    line println
    regexLine := ":(\\w+)!.+PRIVMSG\\s([a-zA-Z0-9_\\-\\#]+)\\s:\\?(\\w+)([\\s+\\w+]+)\\s*(@\\s*(\\w*)\\s*$)?" asRegex dotAll
    (line matchesRegex(regexLine)) ifFalse(return false)
        matches := line matchesOfRegex(regexLine) next
        setSlot("atChannel", matches at(2))
        setSlot("fromUser", matches at(1))
        setSlot("toUser", if(matches at(6), matches at(6), fromUser) .. ": ")
        setSlot("queryAt", matches at(3))
        setSlot("text", matches at(4) asMutable strip)
        line println
    if(queryAt == "git") then(
        queryGit(atChannel, toUser, text)
    ) elseif(queryAt == "tell") then(
        sendToChannel(atChannel, toUser .. text)
    )
    return false
  )

  queryGit := method(sentChannel, replyTo, text,
    searchurl := "http://github.com/api/v2/yaml/repos/search/" .. text replaceSeq(" ", "+") asLowercase
    url := URL with(searchurl)
    url fetch
    gitResponse := url socket readBuffer
    gitData := Gaml process(gitResponse) at(1)
    ircResponse := replyTo .. if(gitData ?username,
        " http://github.com/" .. gitData ?username .."/".. gitData ?name .. " - " .. gitData ?description,
        " No repositories found."
    )
    sendToChannel(sentChannel, ircResponse)
  )

  sendToChannel := method(channel, line,
    send("PRIVMSG " .. channel .. " :" .. line)
  )

  send := method(line,
   socket lnStreamWrite(line)
  )

)

////
// Addons

Socket lnStreamWrite := method(msg, self streamWrite(msg .. "\r\n"))

Gaml := Object clone do(
    match := method(gdoc,
        gdoc allMatchesOfRegex("(---|^.*repositories:.*$|[\"|'].*[\"|']|#(.*)|\\[(.*?)\\]|\{(.*?)\}|[\\w\-]+:|-\\s*\\w+\\s*:|-(.+)|(\\w+.*)|\\d+\\.\\d+|\\d+|\\n+)")
    )
    parse := method(matchList,
        list := List clone
        rkey := "^([\\w\-]+):" asRegex dotAll
        rlist := "^-(.*)" asRegex dotAll
        stack := Object clone
        while(matchList isNotEmpty,
            line := matchList removeFirst at(0)
            if(line matchesRegex("^(.*#+|---|\\n|^.*repositories:.*$)"), continue)
            if(line matchesRegex("-\\s*(\\w+)\\s*:")) then(
                list append(stack)
                stack := Object clone
            ) elseif(line matchesRegex(rkey)) then(
                a := 1
            ) else( continue )
            key := line matchesOfRegex("\\w+") next at(0)
            stack setSlot(key, matchList removeFirst at(0))
        )
        return list
    )
    process := method(gitResponse,
        parse( match(gitResponse) )
    )
)

Gio connect("Gitarion", "irc.freenode.net", "linux-armenia")