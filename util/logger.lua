Logger = {}

Logger.LogLevel = {
    DEBUG = 0, INFO = 1, WARNING = 2
}

Logger.level = Logger.LogLevel.DEBUG

function Logger.stringify(object)
    require('pl.pretty').dump(object)
end

function Logger.print(message, level)
    level = level or Logger.LogLevel.DEBUG
    if(level >= Logger.level) then
        log(message)
    end
end

function Logger.printToConsole(message, level)
    level = level or Logger.LogLevel.DEBUG
    if(level >= Logger.level) then
        print(message)
    end
end

return Logger