' Entry point for the Custom Alarm channel.
sub Main()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Build the main scene defined in components/MainScene.xml
    scene = screen.CreateScene("MainScene")
    screen.show()

    ' Standard SceneGraph event loop. Exit when the screen is closed.
    while true
        msg = wait(0, m.port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
