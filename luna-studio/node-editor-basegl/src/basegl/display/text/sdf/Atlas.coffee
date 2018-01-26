require("modulereg").registerModule __filename, (require __filename)

import * as basegl   from 'basegl/display/Scene'
import * as Property from 'basegl/object/Property'
import * as Shape    from 'basegl/display/Shape'
import * as Image    from 'basegl/display/Image'
import * as OpenType from 'opentype.js'
import * as Promise  from 'bluebird'

import {Symbol, group}   from 'basegl/display/Symbol'
import {BinPack}     from 'basegl/display/text/sdf/BinPack'
import {Composition} from 'basegl/object/Property'
import {typedValue}  from 'basegl/display/Symbol'




letterShape = new Shape.RawShader
  fragment: '''

const int SAMPLENUM = 1;

float foo (float a, float d) {
  float smoothing = zoom * 1.0/64.0;
  return 1. - smoothstep(0.5 - smoothing, 0.5 + smoothing, (a - d));
}

float multisample_gaussian3x3 (mat3 arr, float d) {
    return foo(arr[0][0], d) * 0.011
         + foo(arr[0][1], d) * 0.084
         + foo(arr[0][2], d) * 0.011
         + foo(arr[1][0], d) * 0.084
         + foo(arr[1][1], d) * 0.62
         + foo(arr[1][2], d) * 0.084
         + foo(arr[2][0], d) * 0.011
         + foo(arr[2][1], d) * 0.084
         + foo(arr[2][2], d) * 0.011;
}


void main() {
  float smoothing = zoom * 1.0/64.0;

  float dx = 1./2048.;
  float dy = 1./2048.;

  vec2 uv2 = uv;

  uv2.x /= (glyphsTextureSize / glyphLoc[2]); // width
  uv2.y /= (glyphsTextureSize / glyphLoc[3]); // width
  uv2.x += glyphLoc.x / glyphsTextureSize;
  uv2.y += glyphLoc.y / glyphsTextureSize;

  //uv2.x += 0.1;
  vec4 img = texture2D(glyphsTexture, uv2);
  //float s = img.r;
  vec4 red   = rgb2lch(vec4(1.0,0.0,0.0,1.0));
  vec4 white = rgb2lch(vec4(1.0));
  vec4 cd = white;

  float realZoom = glyphZoom * zoom; // texture is scaled for tests!


  mat3 samples;

  samples[0][0] = texture2D(glyphsTexture, vec2(uv2.x + dx * (-1.*realZoom/2.), uv2.y + dy * (-1.*realZoom/2.))).r;
  samples[0][1] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 0.*realZoom/2.), uv2.y + dy * (-1.*realZoom/2.))).r;
  samples[0][2] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 1.*realZoom/2.), uv2.y + dy * (-1.*realZoom/2.))).r;
  samples[1][0] = texture2D(glyphsTexture, vec2(uv2.x + dx * (-1.*realZoom/2.), uv2.y + dy * ( 0.*realZoom/2.))).r;
  samples[1][1] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 0.*realZoom/2.), uv2.y + dy * ( 0.*realZoom/2.))).r;
  samples[1][2] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 1.*realZoom/2.), uv2.y + dy * ( 0.*realZoom/2.))).r;
  samples[2][0] = texture2D(glyphsTexture, vec2(uv2.x + dx * (-1.*realZoom/2.), uv2.y + dy * ( 1.*realZoom/2.))).r;
  samples[2][1] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 0.*realZoom/2.), uv2.y + dy * ( 1.*realZoom/2.))).r;
  samples[2][2] = texture2D(glyphsTexture, vec2(uv2.x + dx * ( 1.*realZoom/2.), uv2.y + dy * ( 1.*realZoom/2.))).r;

  float s = pow(multisample_gaussian3x3(samples, realZoom/150.0),realZoom/2.);

  float alpha = 1. - smoothstep(0.5 - smoothing, 0.5 + smoothing, img.r);
  //float alpha = s;
  gl_FragColor = vec4(vec3(1.0), alpha);
  //gl_FragColor = vec4((img.rgb - 0.5)*2.0, 1.0);
}

'''


zip = (arrs...) =>
  out = []
  maxLen = Math.min (a.length for a in arrs)...
  for idx in [0...maxLen]
    el = []
    for arr in arrs
      el.push arr[idx]
    out.push el
  out



class IDMap
  constructor: () ->
    @_lastID = 0
    @_map    = new Map

  _nextID: () ->
    id = @_lastID
    @_lastID += 1
    id

  get: (id) ->
    @_map.get id

  insert: (a) ->
    id = @_nextID()
    @_map.set id, a
    id


#####################
### Texture utils ###
#####################

export textureSizeFor  = (i) -> closestPowerOf2 (Math.ceil (Math.sqrt i))
export closestPowerOf2 = (i) -> Math.pow(2, Math.ceil(Math.log2 i))

export encodeArrayInTexture = (arr) ->
  len     = arr.length
  els     = Math.ceil (len/4)
  size    = textureSizeFor els
  tarr    = new Float32Array (size*size*4)
  texture = new Image.DataTexture tarr, size, size, THREE.RGBAFormat, THREE.FloatType
  texture.needsUpdate = true
  for idx in [0...len]
    tarr[idx] = arr[idx]
  {texture, size}



##################
### Glyph path ###
##################

PATH_COMMAND =
  Z: 0 # end of letter
  M: 1
  L: 2
  Q: 3

encodePath    = (path) -> encodePathMut path, []
encodePathMut = (path, cmds) ->
  bbox = path.getBoundingBox()
  offx = bbox.x1
  offy = bbox.y1
  offy2 = bbox.y2
  for segment in path.commands
    switch segment.type
      when 'M' then cmds.push PATH_COMMAND.M, (segment.x - offx) , (segment.y - offy)
      when 'L' then cmds.push PATH_COMMAND.L, (segment.x - offx) , (segment.y - offy)
      when 'Q' then cmds.push PATH_COMMAND.Q, (segment.x1 - offx), (segment.y1 - offy), (segment.x - offx), (segment.y - offy)
      # when 'Z' then cmds.push PATH_COMMAND.Z
  cmds

generatePathsTexture = (paths) ->
  offsets  = [0]
  commands = []
  offset = 0
  for path in paths
    for cmd in encodePath path
      commands.push cmd
      offset += 1
    offsets.push offset
  obj = encodeArrayInTexture commands
  obj.offsets = offsets
  obj





pathFlipYMut = (path) ->
  ncmds = []
  for cmd in path.commands
    ncmd = {type: cmd.type, x: cmd.x, y: -cmd.y}
    if cmd.x1?
      ncmd.x1 = cmd.x1
      ncmd.y1 = -cmd.y1
    ncmds.push ncmd
  path.commands = ncmds
  path


############
### Font ###
############

# export class Font
#   constructor



#############
### Atlas ###
#############

loadFont = Promise.promisify OpenType.load

export class GlyphLocation
  constructor: (@x, @y, @width, @height, @spread) ->

export class GlyphShape
  constructor: (@x, @y, @advanceWidth) ->

export class GlyphInfo
  constructor: (@shape, @loc) ->

export class Atlas extends Composition
  @parameters
    # _scene      : null # FIXME: remove
    _fontFamily : null
    _size       : 2048
    _glyphSize  : 64
    _spread     : 16

  @properties
    _scene     : null
    _texture   : null
    _letterDef : null

  init: () ->
    @_glyphs = new Map
    @_pack   = new BinPack @size, @size
    @_font   = null
    @_rt     = new THREE.WebGLRenderTarget @size, @size
    @_scene  = basegl.scene
      autoUpdate : false
      width      : @size
      height     : @size

    @_texture = new THREE.CanvasTexture @scene.canvas

    @ready = loadFont(@fontFamily).then (font) =>
      @_font = font
      @

    @_letterDef = new Symbol letterShape
    @_letterDef.bbox.xy = [64,64]
    @_letterDef.variables.glyphLoc  = typedValue 'vec4' # FIXME
    @_letterDef.variables.glyphZoom = 1
    @_letterDef.globalVariables.glyphsTexture = @texture
    @_letterDef.globalVariables.glyphsTextureSize = @size

    @_glyphSymbol = new Symbol glyphShape


  getInfo: (glyph) ->
    @_glyphs.get glyph

  loadGlyphs: (args...) ->
    # console.log (64*font.descender/font.unitsPerEm)
    chars = []
    addInput = (a) =>
      if a instanceof Array
        for i in a
          addInput i
      else if typeof a == 'string'
        for char from a
          chars.push a
      else if typeof a == 'number'
        chars.push (String.fromCharCode a)
    addInput args

    glyphPaths = []
    glyphDefs  = []
    locs       = []
    canvas     = {w:0, h:0}
    for char in chars
      glyph     = @_font.charToGlyph char
      path      = pathFlipYMut (@_font.getPath char, 0, 0, @glyphSize)
      pathBBox  = path.getBoundingBox()
      widthRaw  = pathBBox.x2 - pathBBox.x1
      heightRaw = pathBBox.y2 - pathBBox.y1
      width     = widthRaw  + 2*@spread
      height    = heightRaw + 2*@spread
      rect      = @_pack.insert width,height
      if not rect
        throw "Cannot pack letter to atlas, out of space." # TODO: resize atlas
        return false
      canvas.w += width
      canvas.h += Math.max canvas.h, height
      loc       = new GlyphLocation (rect.x + @spread), (rect.y + @spread), widthRaw, heightRaw, @spread
      shape     = new GlyphShape pathBBox.x1, pathBBox.y1, (@glyphSize*glyph.advanceWidth/@_font.unitsPerEm)
      info      = new GlyphInfo shape, loc
      locs.push loc
      @_glyphs.set char, info
      glyphPaths.push path

    shapeDef = generatePathsTexture glyphPaths

    @_glyphSymbol.globalVariables.commands = shapeDef.texture
    @_glyphSymbol.globalVariables.size     = shapeDef.size
    @_glyphSymbol.globalVariables.spread   = @spread
    @_glyphSymbol.variables.offset     = 0
    @_glyphSymbol.variables.nextOffset = 0

    offX = 0
    for [loc, offset, nextOffset] in zip(locs, shapeDef.offsets, shapeDef.offsets.slice(1))
      lx = loc.x - loc.spread
      ly = loc.y - loc.spread
      lw = loc.width  + 2*loc.spread
      lh = loc.height + 2*loc.spread
      glyphInstance = @scene.add @_glyphSymbol
      glyphInstance.position.xy = [lx,ly]
      glyphInstance.bbox.xy     = [lw, lh]
      glyphInstance.variables.offset     = offset
      glyphInstance.variables.nextOffset = nextOffset
      offX += lw

    # FIXME: why we need to call update twice?
    @scene.update()
    @scene.update()
    @texture.needsUpdate = true


  addText: (scene, str) ->
    glyphMaxOff = 2

    newlines = 0
    for char in str
      if char == '\n' then newlines += 1

    offx = 0
    offy = newlines * @glyphSize
    letterSpacing = 0 # FIXME: make related to size
    letters = []
    for char in str
      if char == '\n'
        offx = 0
        offy -= @glyphSize
      else
        letter = scene.add @letterDef
        info   = @getInfo(char)
        loc    = info.loc
        letter.position.xy = [offx, info.shape.y + offy]

        gw = loc.width  + 2*glyphMaxOff
        gh = loc.height + 2*glyphMaxOff
        letter.bbox.xy = [gw,gh]
        letter.variables.glyphLoc = [loc.x - glyphMaxOff, loc.y - glyphMaxOff, gw, gh]
        offx += loc.width + info.shape.advanceWidth + letterSpacing
        letters.push letter

    txt = group letters
    txt




export class FontManager
  constructor: (@_scene) -> #FIXME: scene should be created here
    @atlasses = new IDMap

  load: (cfg) ->
    cfg.scene = @_scene
    atlas = new Atlas cfg
    @atlasses.insert atlas
    atlas




glyphShape = new Shape.RawShader
  fragment: '''

vec4 texture2DRect (sampler2D sampler, float size, vec2 pixel) {
  float x = (0.5 + pixel.x)/size;
  float y = (0.5 + pixel.y)/size;
  return texture2D(sampler,vec2(x,y));
}

float texture2DAs1D (sampler2D sampler, float size, float idx) {
  float el   = floor(idx/4.0);
  float comp = idx - el*4.0;
  float y    = floor(el/size);
  float x    = el - y*size;
  vec4  val  = texture2DRect(sampler, size, vec2(x,y));
  if      (comp == 0.0) { return val.r; }
  else if (comp == 1.0) { return val.g; }
  else if (comp == 2.0) { return val.b; }
  else if (comp == 3.0) { return val.a; }
  else                  { return -1.0;  }
}

void main() {
  vec2 p = local.xy;
  float s = 9999.0;
  vec4 red   = rgb2lch(vec4(1.0,0.0,0.0,1.0));
  vec4 white = rgb2lch(vec4(1.0));
  vec4 cd = white;


  p -= vec2(spread, spread);
  //p -= vec2(1.0);

  vec2 origin = vec2(0.0);

  float idx = floor(offset+0.5);
  bool isInside = false;
  for (float i=0.0; i<1000.0; i++) {
    if (idx>=nextOffset) { break; }
    float cmd = texture2DAs1D(commands, size, idx);
    if        (cmd == 0.0) { break;
    } else if (cmd == 1.0) { // Move
      idx++; float dx = texture2DAs1D(commands, size, idx);
      idx++; float dy = texture2DAs1D(commands, size, idx);
      p -= vec2(dx,dy) - origin;
      origin = vec2(dx,dy);
    } else if (cmd == 2.0) { // Line
      idx++; float tx = texture2DAs1D(commands, size, idx);
      idx++; float ty = texture2DAs1D(commands, size, idx);
      vec2 tp = vec2(tx,ty);
      tp -= origin;
      origin += tp;
      float ns       = sdf_quadraticCurve           (p, tp, tp);
      bool  interior = quadraticCurve_interiorCheck (p, tp, tp);
      isInside = interiorChec_union(isInside, interior);
      s = sdf_union(s,ns);
      p -= tp;
    } else if (cmd == 3.0) { // Quadratic Curve
      idx++; float cx = texture2DAs1D(commands, size, idx);
      idx++; float cy = texture2DAs1D(commands, size, idx);
      idx++; float tx = texture2DAs1D(commands, size, idx);
      idx++; float ty = texture2DAs1D(commands, size, idx);
      vec2 cp = vec2(cx,cy);
      vec2 tp = vec2(tx,ty);
      cp -= origin;
      tp -= origin;
      origin += tp;
      float ns       = sdf_quadraticCurve           (p, cp, tp);
      bool  interior = quadraticCurve_interiorCheck (p, cp, tp);
      isInside = interiorChec_union(isInside, interior);
      s = sdf_union(s,ns);
      p -= tp;
    }
    idx++;
  }
  if (isInside) { s = -s; }

  float d = s/(2.*spread) + .5;
  //d = s/spread;

  gl_FragColor = vec4(vec3(d),1.0);
  //return sdf_shape(d, 0, vec4(0.0), cd);
}

'''
