cc = process.atomBinding 'bignum'

BigNum = cc.BigNum
module.exports = BigNum

BigNum.conditionArgs = (num, base) ->
  if typeof num != 'string'
    num = num.toString(base or 10)
  if num.match(/e\+/)
    # positive exponent
    if !Number(num).toString().match(/e\+/)
      {
        num: Math.floor(Number(num)).toString()
        base: 10
      }
    else
      pow = Math.ceil(Math.log(num) / Math.log(2))
      n = (num / 2 ** pow).toString(2).replace(/^0/, '')
      i = n.length - n.indexOf('.')
      n = n.replace(/\./, '')
      while i <= pow
        n += '0'
        i++
      {
        num: n
        base: 2
      }
  else if num.match(/e\-/)
    # negative exponent
    {
      num: Math.floor(Number(num)).toString()
      base: base or 10
    }
  else
    {
      num: num
      base: base or 10
    }

cc.setJSConditioner BigNum.conditionArgs

BigNum.isBigNum = (num) ->
  if !num
    return false
  for key of BigNum.prototype
    if !num[key]
      return false
  true

BigNum::inspect = ->
  '<BigNum ' + @toString(10) + '>'

BigNum::toString = (base) ->
  value = undefined
  if base
    value = @tostring(base)
  else
    value = @tostring()
  if base > 10 and 'string' == typeof value
    value = value.toLowerCase()
  value

BigNum::toNumber = ->
  parseInt @toString(), 10

[
  'add'
  'sub'
  'mul'
  'div'
  'mod'
].forEach (op) ->

  BigNum.prototype[op] = (num) ->
    `var x`
    if BigNum.isBigNum(num)
      return @['b' + op](num)
    else if typeof num == 'number'
      if num >= 0
        return @['u' + op](num)
      else if op == 'add'
        return @usub(-num)
      else if op == 'sub'
        return @uadd(-num)
      else
        x = BigNum(num)
        return @['b' + op](x)
    else if typeof num == 'string'
      x = BigNum(num)
      return @['b' + op](x)
    else
      throw new TypeError('Unspecified operation for type ' + typeof num + ' for ' + op)
    return

  return

BigNum::abs = ->
  @babs()

BigNum::neg = ->
  @bneg()

BigNum::powm = (num, mod) ->
  m = undefined
  res = undefined
  if typeof mod == 'number' or typeof mod == 'string'
    m = BigNum(mod)
  else if BigNum.isBigNum(mod)
    m = mod
  if typeof num == 'number'
    return @upowm(num, m)
  else if typeof num == 'string'
    n = BigNum(num)
    return @bpowm(n, m)
  else if BigNum.isBigNum(num)
    return @bpowm(num, m)
  return

BigNum::mod = (num, mod) ->
  m = undefined
  res = undefined
  if typeof mod == 'number' or typeof mod == 'string'
    m = BigNum(mod)
  else if BigNum.isBigNum(mod)
    m = mod
  if typeof num == 'number'
    return @umod(num, m)
  else if typeof num == 'string'
    n = BigNum(num)
    return @bmod(n, m)
  else if BigNum.isBigNum(num)
    return @bmod(num, m)
  return

BigNum::pow = (num) ->
  if typeof num == 'number'
    if num >= 0
      @upow num
    else
      BigNum::powm.call this, num, this
  else
    x = parseInt(num.toString(), 10)
    BigNum::pow.call this, x

BigNum::shiftLeft = (num) ->
  if typeof num == 'number'
    if num >= 0
      @umul2exp num
    else
      @shiftRight -num
  else
    x = parseInt(num.toString(), 10)
    BigNum::shiftLeft.call this, x

BigNum::shiftRight = (num) ->
  if typeof num == 'number'
    if num >= 0
      @udiv2exp num
    else
      @shiftLeft -num
  else
    x = parseInt(num.toString(), 10)
    BigNum::shiftRight.call this, x

BigNum::cmp = (num) ->
  if BigNum.isBigNum(num)
    @bcompare num
  else if typeof num == 'number'
    if num < 0
      @scompare num
    else
      @ucompare num
  else
    x = BigNum(num)
    @bcompare x

BigNum::gt = (num) ->
  @cmp(num) > 0

BigNum::ge = (num) ->
  @cmp(num) >= 0

BigNum::eq = (num) ->
  @cmp(num) == 0

BigNum::ne = (num) ->
  @cmp(num) != 0

BigNum::lt = (num) ->
  @cmp(num) < 0

BigNum::le = (num) ->
  @cmp(num) <= 0

'and or xor'.split(' ').forEach (name) ->

  BigNum.prototype[name] = (num) ->
    if BigNum.isBigNum(num)
      @['b' + name] num
    else
      x = BigNum(num)
      @['b' + name] x

  return

BigNum::sqrt = ->
  @bsqrt()

BigNum::root = (num) ->
  if BigNum.isBigNum(num)
    @broot num
  else
    x = BigNum(num)
    @broot num

BigNum::rand = (to) ->
  if to == undefined
    if @toString() == '1'
      BigNum 0
    else
      @brand0()
  else
    x = if BigNum.isBigNum(to) then to.sub(this) else BigNum(to).sub(this)
    x.brand0().add this

BigNum::invertm = (mod) ->
  if BigNum.isBigNum(mod)
    @binvertm mod
  else
    x = BigNum(mod)
    @binvertm x

BigNum.prime = (bits, safe) ->
  if 'undefined' == typeof safe
    safe = true
  # Force uint32
  bits >>>= 0
  BigNum.uprime0 bits, ! !safe

BigNum::probPrime = (reps) ->
  n = @probprime(reps or 10)
  {
    1: true
    0: false
  }[n]

BigNum::nextPrime = ->
  num = this
  loop
    num = num.add(1)
    unless !num.probPrime()
      break
  num

BigNum::isBitSet = (n) ->
  @isbitset(n) == 1

BigNum.fromBuffer = (buf, opts) ->
  if !opts
    opts = {}
  endian = {
    1: 'big'
    '-1': 'little'
  }[opts.endian] or opts.endian or 'big'
  size = if opts.size == 'auto' then Math.ceil(buf.length) else opts.size or 1
  if buf.length % size != 0
    throw new RangeError('Buffer length (' + buf.length + ')' + ' must be a multiple of size (' + size + ')')
  hex = []
  i = 0
  while i < buf.length
    chunk = []
    j = 0
    while j < size
      chunk.push buf[i + (if endian == 'big' then j else size - j - 1)]
      j++
    hex.push chunk.map((c) ->
      (if c < 16 then '0' else '') + c.toString(16)
    ).join('')
    i += size
  BigNum hex.join(''), 16

BigNum::toBuffer = (opts) ->
  `var buf`
  `var len`
  if typeof opts == 'string'
    if opts != 'mpint'
      return 'Unsupported Buffer representation'
    abs = @abs()
    buf = abs.toBuffer(
      size: 1
      endian: 'big')
    len = if buf.length == 1 and buf[0] == 0 then 0 else buf.length
    if buf[0] & 0x80
      len++
    ret = new Buffer(4 + len)
    if len > 0
      buf.copy ret, 4 + (if buf[0] & 0x80 then 1 else 0)
    if buf[0] & 0x80
      ret[4] = 0
    ret[0] = len & 0xff << 24
    ret[1] = len & 0xff << 16
    ret[2] = len & 0xff << 8
    ret[3] = len & 0xff << 0
    # two's compliment for negative integers:
    isNeg = @lt(0)
    if isNeg
      i = 4
      while i < ret.length
        ret[i] = 0xff - (ret[i])
        i++
    ret[4] = ret[4] & 0x7f | (if isNeg then 0x80 else 0)
    if isNeg
      ret[ret.length - 1]++
    return ret
  if !opts
    opts = {}
  endian = {
    1: 'big'
    '-1': 'little'
  }[opts.endian] or opts.endian or 'big'
  hex = @toString(16)
  if hex.charAt(0) == '-'
    throw new Error('converting negative numbers to Buffers not supported yet')
  size = if opts.size == 'auto' then Math.ceil(hex.length / 2) else opts.size or 1
  len = Math.ceil(hex.length / (2 * size)) * size
  buf = new Buffer(len)
  # zero-pad the hex string so the chunks are all `size` long
  while hex.length < 2 * len
    hex = '0' + hex
  hx = hex.split(new RegExp('(.{' + 2 * size + '})')).filter((s) ->
    s.length > 0
  )
  hx.forEach (chunk, i) ->
    j = 0
    while j < size
      ix = i * size + (if endian == 'big' then j else size - j - 1)
      buf[ix] = parseInt(chunk.slice(j * 2, j * 2 + 2), 16)
      j++
    return
  buf

Object.keys(BigNum.prototype).forEach (name) ->
  if name == 'inspect' or name == 'toString'
    return

  BigNum[name] = (num) ->
    args = [].slice.call(arguments, 1)
    if BigNum.isBigNum(num)
      num[name].apply num, args
    else
      bigi = BigNum(num)
      bigi[name].apply bigi, args

  return
