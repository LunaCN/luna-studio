require("modulereg").registerModule __filename, (require __filename)

import {Vector}           from "basegl/math/Vector"
import {animationManager} from "basegl/animation/Manager"


#################
### Navigator ###
#################

export class Navigator
  @ACTION:
    PAN : 'PAN'
    ZOOM: 'ZOOM'

  constructor: (@scene) ->
    @zoomFactor   = 1
    @drag         = 10
    @springCoeff  = 1.5
    @mass         = 20
    @minDist      = 0.1
    @maxDist      = 10
    @maxVel       = 1
    @minVel       = 0.001

    @vel          = new Vector
    @acc          = new Vector
    @desiredPos   = Vector.fromXYZ @scene.camera.position
    @campos       = null
    @action       = null
    @started      = false

    @scene.domElement.addEventListener 'mousedown'  , @onMouseDown
    @scene.domElement.addEventListener 'contextmenu', @onContextMenu
    document.addEventListener          'mouseup'    , @onMouseUp

    animationManager.addConstantRateAnimation @.onEveryFrame


  onEveryFrame: () =>
    camDelta    = @desiredPos.sub @scene.camera.position
    camDeltaLen = camDelta.length()
    forceVal    = camDeltaLen * @springCoeff
    force       = camDelta.normalize().mul forceVal
    force.z     = camDelta.z * @springCoeff
    acc         = force.div @mass

    @vel.addMut acc
    newVelVal = @vel.length()

    if newVelVal < @minVel
      @vel.zeroMut()
      @scene.camera.position.x = @desiredPos.x
      @scene.camera.position.y = @desiredPos.y
      @scene.camera.position.z = @desiredPos.z
    else
      @vel = @vel.normalize().mul newVelVal
      @scene.camera.position.x += @vel.x
      @scene.camera.position.y += @vel.y
      @scene.camera.position.z += @vel.z

      if newVelVal != 0
        @vel = @vel.div (1 + @drag * newVelVal)


  onMouseDown: (event) =>
    document.addEventListener 'mousemove', @onMouseMove
    @started = false
    @campos  = Vector.fromXYZ @scene.camera.position

    switch event.button
      when 2 then @action = Navigator.ACTION.ZOOM
      when 1 then @action = Navigator.ACTION.PAN
      else @action = null

    rx =   (event.offsetX / @scene.width  - 0.5)
    ry = - (event.offsetY / @scene.height - 0.5)

    [visibleWidth, visibleHeight] = @scene.visibleSpace()
    @clickPoint = new Vector [@scene.camera.position.x + rx * visibleWidth, @scene.camera.position.y + ry * visibleHeight, 0]
    @camPath    = @clickPoint.sub @scene.camera.position
    camPathNorm = @camPath.normalize()
    @camPath    = camPathNorm.div Math.abs(camPathNorm.z)


  onMouseMove: (event) =>
    movement = new Vector [event.movementX, event.movementY, 0]

    if @action == Navigator.ACTION.ZOOM
      movementDeltaLen2 = movement.length()
      applyDir          = (a) => if event.movementX < event.movementY then a.negate() else a
      trans             = applyDir (@camPath.mul (Math.abs (@scene.camera.position.z) * movementDeltaLen2 / 100))
      @desiredPos       = @desiredPos.add trans
      limit             = null
      if      (@desiredPos.z < @minDist) then limit = @minDist
      else if (@desiredPos.z > @maxDist) then limit = @maxDist
      if limit
        transNorm   = trans.normalize()
        transFix    = transNorm.div(transNorm.z).mul(limit-@desiredPos.z)
        @desiredPos = @desiredPos.add transFix

    else if @action == Navigator.ACTION.PAN
      [visibleWidth, visibleHeight] = @scene.visibleSpace()
      @desiredPos.x -= movement.x * (visibleWidth  / @scene.width)
      @desiredPos.y += movement.y * (visibleHeight / @scene.height)

  onMouseUp:     (event) => document.removeEventListener 'mousemove', @onMouseMove
  onContextMenu: (event) => event.preventDefault();
