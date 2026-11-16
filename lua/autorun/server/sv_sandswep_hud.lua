resource.AddSingleFile("resource/fonts/Oswald-Regular.ttf")
for _, name in ipairs(file.Find("materials/sandswep/hud/*.png", "GAME")) do
    resource.AddSingleFile("materials/sandswep/hud/" .. name)
end
