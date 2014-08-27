# 


class SystemTestsCommandTurnOffMorphsGeometryInfoInLabels extends SystemTestsCommand

  @replayFunction: (systemTestsRecorderAndPlayer, commandBeingPlayed) ->
    systemTestsRecorderAndPlayer.turnOffMorphsGeometryInfoInLabels()


  constructor: (systemTestsRecorderAndPlayer) ->
    super(systemTestsRecorderAndPlayer)
    # it's important that this is the same name of
    # the class cause we need to use the static method
    # replayFunction to replay the command
    @testCommandName = "SystemTestsCommandTurnOffMorphsGeometryInfoInLabels"
