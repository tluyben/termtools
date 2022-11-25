function printf(s,...)  print(s:format(...)) end
wather = hs.caffeinate.watcher.new(function(eventType)    
    -- screensDidWake, systemDidWake, screensDidUnlock
    if eventType == hs.caffeinate.watcher.systemDidWake then
        local output = hs.execute("~/wakeywakey", false)
        hs.notify.new({title="Startup wakeywakey", informativeText=output}):send()
        printf("%s", output)
    end
end)
wather:start()
