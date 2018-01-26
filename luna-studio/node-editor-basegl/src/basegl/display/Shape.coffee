require("modulereg").registerModule __filename, (require __filename)

import {StyledObject}  from 'basegl/display/DisplayObject'
import {consAlias}     from 'basegl/object/Property'
import {vector, point} from 'basegl/math/Vector'

import * as M          from 'basegl/math/Common'
import * as Color      from 'basegl/display/Color'
import * as GLSL       from 'basegl/display/target/WebGL'
import * as TypeClass  from 'TypeClass'


vertexHeader   = require('shader/component/vertexHeader.glsl').replace('#define GLSLIFY 1','');
vertexBody     = require('shader/component/vertexBody.glsl').replace('#define GLSLIFY 1','');
fragmentHeader = require('shader/component/fragmentHeader.glsl').replace('#define GLSLIFY 1','');
fragmentRunner = require('shader/component/fragmentRunner.glsl').replace('#define GLSLIFY 1','');
fragment_lib   = require('shader/sdf/sdf.glsl').replace('#define GLSLIFY 1','');


import {parensed, glslCall} from 'text/CodeGen'




mkBBName      = (n) -> n + '_bb'
mkIDName      = (n) -> n + '_id'
mkCDName      = (n) -> n + '_cd'
mkShapeName   = (n) -> 'shape_' + n
mkShapeIDName = (n) -> mkIDName(mkShapeName(n))



##################
### SDF Canvas ###
##################

defCdC = Color.rgb [1,0,0,1]
defCd  = "rgb2lch(#{GLSL.toCode defCdC})"

export class CanvasShape
  constructor: (@shapeNum, @id) ->
    @name   = mkShapeName @shapeNum
    @idName = mkIDName @name
    @bbName = mkBBName @name
    @cdName = mkCDName @name

export class Canvas
  constructor: () ->
    @shapeNum  = 0
    @lastID    = 1 # FIXME - use 0 as background
    @bbLines   = []
    @codeLines = []

  getNewID: () ->
    id = @lastID
    @lastID += 1
    id

  genNewColorID: (name) =>
    id = @getNewID()
    @addCodeLine "int #{mkIDName name} = newIDLayer(#{name}, #{id});"
    id

  mergeIDLayers: (a,b) => (name) =>
    @addCodeLine "int #{mkIDName name} = id_union(#{a.name}, #{b.name}, #{a.idName}, #{b.idName});"
    null

  diffIDLayers: (a,b) => (name) =>
    @addCodeLine "int #{mkIDName name} = id_difference(#{a.name}, #{b.name}, #{a.idName});"
    null


  keepIDLayer: (a) => (name) =>
    @addCodeLine "int #{mkIDName name} = #{mkIDName a.name};"
    null

  addCodeLine: (c) -> @codeLines.push c
  addBBLine:   (c) -> @bbLines.push c

  code: () ->
    @codeLines.join '\n'

  defShape: (sdf, bb, cd=defCd, generateID=@genNewColorID) ->
    @shapeNum += 1
    shape = new CanvasShape @shapeNum

    @addCodeLine "float #{shape.name}   = #{sdf};"
    @addCodeLine "vec4  #{shape.bbName} = #{bb};"
    @addCodeLine "vec4  #{shape.cdName} = #{cd};"
    shape.id = generateID shape.name
    shape

  circle: (r, angle=0) ->
    g_r  = GLSL.toCode r
    bb   = "bbox_new(#{g_r},#{g_r})"
    glsl = switch angle
      when 0 then "sdf_circle(p,#{g_r})"
      else        "sdf_circle(p,#{g_r}, #{GLSL.toCode angle})"
    @defShape glsl, bb

  rect: (w,h, rs...) ->
    g_w  = GLSL.toCode w
    g_h  = GLSL.toCode h
    bb   = "bbox_new(#{g_w}/2.0,#{g_h}/2.0)"
    glsl = switch rs.length
      when 0 then "sdf_rect(p,vec2(#{g_w}, #{g_h}));"
      when 1 then "sdf_rect(p,vec2(#{g_w}, #{g_h}), #{GLSL.toCode rs[0]});"
      when 2 then "sdf_rect(p,vec2(#{g_w}, #{g_h}), vec4(#{GLSL.toCode rs[0]},#{GLSL.toCode rs[1]},#{GLSL.toCode rs[1]},#{GLSL.toCode rs[1]}));"
      when 3 then "sdf_rect(p,vec2(#{g_w}, #{g_h}), vec4(#{GLSL.toCode rs[0]},#{GLSL.toCode rs[1]},#{GLSL.toCode rs[2]},#{GLSL.toCode rs[2]}));"
      else        "sdf_rect(p,vec2(#{g_w}, #{g_h}), vec4(#{GLSL.toCode rs[0]},#{GLSL.toCode rs[1]},#{GLSL.toCode rs[2]},#{GLSL.toCode rs[3]}));"
    @defShape glsl, bb

  quadraticCurveTo: (cx,cy,x,y) ->
    g_cx = GLSL.toCode cx
    g_cy = GLSL.toCode cy
    g_x  = GLSL.toCode x
    g_y  = GLSL.toCode y
    bb   = "bbox_new(0.0, 0.0)" # FIXME: http://pomax.nihongoresources.com/pages/bezier/
    glsl = "sdf_quadraticCurve(p, vec2(#{g_cx},#{g_cy}), vec2(#{g_x},#{g_y}));"
    @defShape glsl, bb

  union:         (s1,s2)   -> @defShape "sdf_union(#{s1.name},#{s2.name})"      , "bbox_union(#{s1.bbName},#{s2.bbName})"    , "color_mergeLCH(#{s1.name},#{s2.name},#{s1.cdName},#{s2.cdName})", @mergeIDLayers(s1,s2)
  unionRound:    (r,s1,s2) -> @defShape "sdf_unionRound(#{s1.name},#{s2.name},#{GLSL.toCode r})"      , "bbox_union(#{s1.bbName},#{s2.bbName})"    , "color_mergeLCH(#{s1.name},#{s2.name},#{s1.cdName},#{s2.cdName})", @mergeIDLayers(s1,s2)
  difference:    (s1,s2)   -> @defShape "sdf_difference(#{s1.name},#{s2.name})" , "bbox_union(#{s1.bbName},#{s2.bbName})"    , s1.cdName, @diffIDLayers(s1,s2)
  grow:          (s1,r)    -> @defShape "sdf_grow(#{GLSL.toCode r},#{s1.name})" , "bbox_grow(#{GLSL.toCode r},#{s1.bbName})" , s1.cdName
  outside:       (s1)      -> @defShape "sdf_removeInside(#{s1.name})"          , s1.bbName                                  , s1.cdName
  inside:        (s1)      -> @defShape "sdf_removeOutside(#{s1.name})"         , s1.bbName                                  , s1.cdName, @keepIDLayer(s1)
  blur:          (s1,r)    -> @defShape "sdf_blur(#{s1.name},#{GLSL.toCode r})" , "bbox_grow(#{GLSL.toCode r},#{s1.bbName})" , s1.cdName
  move:          (x,y)     -> @addCodeLine "p = sdf_translate(p, vec2(#{GLSL.toCode x}, #{GLSL.toCode y}));"
  moveTo:        (x,y)     -> @addCodeLine "p = vec2(#{GLSL.toCode x}, #{GLSL.toCode y});"
  rotate:        (a)       -> @addCodeLine "p = sdf_rotate(p, #{GLSL.toCode a});"
  moveTo:        (x,y)     -> @addCodeLine "p = vec2(#{GLSL.toCode x}, #{GLSL.toCode y});"
  fill:          (s1,c)    ->
    c = c.toRGB()
    if c.a == undefined
      c = c.copy()
      c.a = 1
    cc = "rgb2lch(toLinear(#{GLSL.toCode c}))"
    @defShape s1.name, s1.bbName, cc, @keepIDLayer(s1)




  glslShape: (code, bbox="vec4(0.0,0.0,0.0,0.0)") -> @defShape code, bbox



###################
### SDF Objects ###
###################


# FIXME: Use M.<func> instad of basegl_sdfResolve. If resolve have to still be used, use typeclasses instead
# FIXME: Make basegl_sdfResolve like standard - check if everything implements it
# FIXME: Allow bboxes to be accessed as js struct / glsl code like everything else now
Number::basegl_sdfResolve = () -> @
String::basegl_sdfResolve = () -> @


resolve = (r,a) -> a.basegl_sdfResolve(r)

export negate = (a) -> a.basegl_sdfNegate()
Number::basegl_sdfNegate = () -> -@
String::basegl_sdfNegate = () -> '-' + @


export class BBox
  constructor: (@left, @top, @right, @bottom) ->

  basegl_sdfResolve: (r) -> new BBox (resolve r,@left), (resolve r,@top), (resolve r,@right), (resolve r,@bottom)


export class GLSLObjectRef
  constructor: (@shape, @selector) ->
    @_post = (a) => a

  copy: () -> new GLSLObjectRef @shape, @selector

  basegl_sdfNegate: () ->
    ref = @.copy()
    ref._post = (a) => (@_post a).basegl_sdfNegate()
    ref

  basegl_sdfResolve: (r) -> @_post (@selector (r.renderShape @shape))


glslBBRef = (shape, idx) -> new GLSLObjectRef shape, ((s) => s.bbName + '[' + idx + ']')

protoBind     = (f) -> (args...) -> f @, args...
protoBindCons = (t) -> protoBind (consAlias t)

export class Shape extends StyledObject
  constructor: () ->
    super()
    @type  = Shape
    @_bbox = new BBox (glslBBRef @, 0), (glslBBRef @, 1), (glslBBRef @, 2), (glslBBRef @, 3)

  TypeClass.implement @, M.add, (args...) -> @add args...
  TypeClass.implement @, M.sub, (args...) -> @sub args...

  @getter 'bbox', -> @_bbox



#############
### Prims ###
#############

export class Circle extends Shape
  constructor: (@radius, @angle=0) -> super()
  renderGLSL: (r) -> r.canvas.circle @radius, @angle
export circle = consAlias Circle

export class Rect extends Shape
  constructor: (@width, @height, @radiuses...) -> super()
  renderGLSL: (r) -> r.canvas.rect @width, @height, @radiuses...
export rect = consAlias Rect



##############
### Curves ###
##############

export class QuadraticCurve extends Shape
  constructor: (@control,@destination) -> super()
  renderGLSL: (r) -> r.canvas.quadraticCurveTo(@control.x, @control.y, @destination.x, @destination.y)
export quadraticCurve = consAlias QuadraticCurve

export class Path extends Shape
  constructor: (@segments) -> super(); @addChildren @segments...
  renderGLSL: (r) ->
    rsegments = []
    interiors = []
    offset    = point 0,0

    r.withNewTxCtx () =>
      for curve in @segments
        r.canvas.move offset.x, offset.y
        rs       = r.renderShape curve
        offset   = curve.destination
        interior = "#{rs.name}_pathInterior"
        r.canvas.addCodeLine "bool #{interior} = quadraticCurve_interiorCheck(p, vec2(#{curve.control.x},#{curve.control.y}), vec2(#{curve.destination.x},#{curve.destination.y}));"
        rsegments.push rs
        interiors.push interior

    path = fold (r.canvas.union.bind r.canvas), rsegments
    interiorCheckExpr = GLSL.callRec 'interiorChec_union', interiors
    interior = "#{path.name}_pathInterior"

    r.canvas.addCodeLine "bool #{interior} = #{interiorCheckExpr};"
    shape = r.canvas.defShape "(#{interior}) ? (-#{path.name}) : (#{path.name})", "bbox_new(0.0, 0.0)"
    shape
export path = consAlias Path




#foldl :: (a -> b -> a) -> a -> [b] -> a
fold  = (f, bs) => foldl f, bs[0], bs.slice(1)
foldl = (f, a, bs) =>
  if bs.length == 0 then a
  else foldl f, f(a,bs[0]), bs.slice(1)

# foldl = (f, a, bs) => f a, bs[0]

################
### Booleans ###
################

export class Union extends Shape
  constructor: (@shapes...) -> super(); @addChildren @shapes...
  renderGLSL: (r) ->
    rs = r.renderShapes @shapes...
    fold (r.canvas.union.bind r.canvas), rs
Shape::union = protoBindCons Union
export union = consAlias Union

export class UnionRound extends Shape
  constructor: (@radius, @shapes...) -> super(); @addChildren @shapes...
  renderGLSL: (r) ->
    rs = r.renderShapes @shapes...
    fold ((a,b) => (r.canvas.unionRound.bind r.canvas) @radius,a,b), rs
export unionRound = consAlias UnionRound


export class Difference extends Shape
  constructor: (@a, @b) -> super(); @addChildren @a, @b
  renderGLSL: (r) ->
    [a, b] = r.renderShapes @a, @b
    r.canvas.difference a,b
Shape::difference = protoBindCons Difference



########################
### SDF Modification ###
########################

export class Grow extends Shape
  constructor: (@a, @radius) -> super(); @addChildren @a
  renderGLSL: (r) ->
    a = r.renderShape @a
    r.canvas.grow a, @radius
Shape::grow = protoBindCons Grow
Shape::shrink = (radius) -> @grow(-radius)

export class Inside extends Shape
  constructor: (@a) -> super(); @addChildren @a
  renderGLSL: (r) ->
    a = r.renderShape @a
    r.canvas.inside a
Shape::inside = protoBindCons Inside



##################
### Transforms ###
##################

export class Move extends Shape
  constructor: (@a, @x, @y) -> super(); @addChildren @a
  renderGLSL: (r) ->
    r_x = resolve r, @x
    r_y = resolve r, @y
    r.withNewTxCtx () =>
      r.canvas.move r_x, r_y
      r.renderShape @a
Shape::move  = protoBindCons Move
Shape::moveX = (x) -> @move x,0
Shape::moveY = (y) -> @move 0,y

export class Rotate extends Shape
  constructor: (@a, @angle) -> super(); @addChildren @a
  renderGLSL: (r) -> r.withNewTxCtx () =>
    r.canvas.rotate (-@angle)
    r.renderShape @a
Shape :: rotate = protoBindCons Rotate



###############
### Filters ###
###############

export class Blur extends Shape
  constructor: (@a, @radius) -> super(); @addChildren @a
  renderGLSL: (r) ->
    a = r.renderShape @a
    r.canvas.blur a, @radius
Shape::blur = protoBindCons Blur



#############
### Color ###
#############

export class Fill extends Shape
  constructor: (@a, @color) -> super(); @addChildren @a
  renderGLSL: (r) ->
    a = r.renderShape @a
    r.canvas.fill a, @color
Shape::fill = protoBindCons Fill







export class CodeCtx extends Shape
  constructor: (@a, @post=()->"") -> super(); @addChildren @a
  renderGLSL: (r) ->
    a = r.renderShape @a
    r.canvas.defShape (@post a)

export class GLSLShape extends Shape
  constructor: (@code) -> super()
  renderGLSL: (r) ->
    r.canvas.glslShape @code


### Smart Constructors ###

### Primitive shapes ###

### Booleans ###

### ... ###
# export grow          = consAlias Grow
export inside        = consAlias Inside
export codeCtx       = consAlias CodeCtx
export glslShape     = consAlias GLSLShape




alignL = (a) -> a.move (negate a.bbox.left)  , 0
alignR = (a) -> a.move (negate a.bbox.right) , 0
alignT = (a) -> a.move 0, a.bbox.top
alignB = (a) -> a.move 0, a.bbox.bottom

alignTL = (a) -> alignT (alignL  a)
alignTR = (a) -> alignT (alignR a)
alignBL = (a) -> alignB (alignL  a)
alignBR = (a) -> alignB (alignR a)


### Extensions ###


Shape::alignTL = (args...) -> alignTL @, args...
Shape::inside  = (args...) -> inside @, args...
Shape.getter 'inside', -> inside @
Shape.getter 'alignedTL', -> alignTL @
Shape.getter 'alignedTR', -> alignTR @
Shape.getter 'alignedBL', -> alignBL @
Shape.getter 'alignedBR', -> alignBR @
Shape.getter 'alignedL' , -> alignL @
Shape.getter 'alignedR' , -> alignR @
Shape.getter 'alignedT' , -> alignT @
Shape.getter 'alignedB' , -> alignB @


Shape::sub = (args...) -> @.difference args...
Shape::add = (args...) -> @.union args...


export class GLSLRenderer
  constructor: (@defs=[]) ->
    @canvas    = new Canvas
    @done      = new Map
    @idmap     = new Map
    @txCtx     = 0
    @txCtxNext = @txCtx + 1

  getNewTxCtx: () ->
    ctx         = @txCtxNext
    @txCtx      = ctx
    @txCtxNext += 1
    ctx

  withNewTxCtx: (f) ->
    oldCtx = @txCtx
    newCtx = @getNewTxCtx()
    @canvas.addCodeLine "vec2 pp#{newCtx} = p;"
    out    = f(newCtx)
    @canvas.addCodeLine "p = pp#{newCtx};"
    @txCtx = oldCtx
    out

  renderShape: (shape) ->
    shapeCache = @done.get(shape)
    if shapeCache != undefined
        canvasShape = shapeCache[@txCtx]
        if canvasShape != undefined then return canvasShape
    else
      shapeCache = {}

    sdef = shape.renderGLSL @
    shapeCache[@txCtx] = sdef
    if sdef.id? then @idmap.set sdef.id, shape
    @done.set(shape, shapeCache)

    return sdef

  renderShapes: (shapes...) ->
    @renderShape shape for shape in shapes

  render: (s) ->
    shape    = @renderShape(s)
    defsCode = 'sdf_shape main(vec2 p) {\n' + @canvas.code() + "\nreturn sdf_shape(#{shape.name}, #{shape.idName}, #{shape.bbName}, #{shape.cdName});\n}"
    new ShaderBuilder (new SDFShader {fragment: defsCode}), @idmap





class ShaderBuilder
  constructor: (@fragment, @idmap=null, @attributes=null, @uniforms=null) ->

  compute: () ->
    body      = []
    vertDecls = []
    fragDecls = []
    if @attributes? then for [name, v] from @attributes
      varyingDecl =  "varying   #{v.type}   #{name};"
      vertDecls.push "attribute #{v.type} v_#{name};"
      vertDecls.push varyingDecl
      fragDecls.push varyingDecl
      body.push "#{name} = v_#{name};"
    if @uniforms? then for [name, v] from @uniforms
      uniformDecl = "uniform #{v.type} #{name};"
      vertDecls.push uniformDecl
      fragDecls.push uniformDecl

    body      = body.join '\n'
    vertDecls = vertDecls.join '\n'
    fragDecls = fragDecls.join '\n'
    vertex    = [vertexHeader  , vertDecls, 'void main() {', vertexBody, body, '}'].join('\n')
    fragment  = [fragmentHeader, fragDecls, fragment_lib, @fragment.genFragmentCode()].join('\n')
    {vertex, fragment}



export class Shader
  toShader: () -> new ShaderBuilder @


# FIXME: handle vertex shader
export class RawShader extends Shader
  constructor: (cfg) ->
    super()
    @vertex   = cfg.vertex
    @fragment = cfg.fragment

  genFragmentCode: () -> @fragment



# FIXME: handle vertex shader
export class SDFShader extends Shader
  constructor: (cfg) ->
    super()
    @vertex   = cfg.vertex
    @fragment = cfg.fragment

  genFragmentCode: () ->
    def  = @fragment.replace (/^sdf_shape\s+main/m), 'sdf_shape _main'
    code = [def, fragmentRunner].join '\n'
    code


Shape::toShader = () -> (new GLSLRenderer).render @
