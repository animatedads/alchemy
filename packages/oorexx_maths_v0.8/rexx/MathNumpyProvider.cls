/* Optional accelerated binary64 provider using existing Foreign Runtime. */
ignored=.Maths~registerProvider(.MathNumpyProvider~new)

::class MathNumpyProvider subclass MathProvider public
::method init
  expose _np _version _pythonVersion _providerPath _blasName _blasVersion _lapackName _lapackVersion
  if \.ForeignPython~canImport('numpy') then raise syntax 88.900 array('importable numpy','not available')
  _np=.ForeignPython~import('numpy')
  _version=_np~get('__version__')
  _pythonVersion=_np~pythonVersion
  _providerPath=_np~providerPath
  _blasName='unknown'; _blasVersion='unknown'; _lapackName='unknown'; _lapackVersion='unknown'
  cfg=_np~get('__config__')
  conf=cfg~get('CONFIG')
  if conf~isA(.directory) then if conf~hasIndex('Build Dependencies') then do
    deps=conf['Build Dependencies']
    if deps~isA(.directory) then do
      if deps~hasIndex('blas') then do
        b=deps['blas']; if b~isA(.directory) then do; _blasName=b['name']; _blasVersion=b['version']; end
      end
      if deps~hasIndex('lapack') then do
        l=deps['lapack']; if l~isA(.directory) then do; _lapackName=l['name']; _lapackVersion=l['version']; end
      end
    end
  end
  cfg~close
::method name; return 'NUMPY'
::method version; expose _version; return _version
::method supports
  use strict arg operation
  return operation='matrix.add' | operation='matrix.sub' | operation='matrix.mul' | operation='matrix.transpose' | operation='matrix.solve'
::method _array
  expose _np
  use strict arg matrix
  if matrix~backendProvider='NUMPY' & matrix~backendValue \== .nil then return .array~of(matrix~backendValue,.false)
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  return .array~of(_np~array(matrix~toArray,kw),.true)
::method _evidence
  expose _pythonVersion _providerPath _blasName _blasVersion _lapackName _lapackVersion
  use strict arg operation,context,inputs,algorithm,details=''
  stack='python='_pythonVersion';module='_providerPath';BLAS='_blasName' '_blasVersion';LAPACK='_lapackName' '_lapackVersion
  if details<>'' then stack=stack';'_details
  ev=.MathEvidence~new(operation,context,inputs)
  ev~addStep(.MathPathStep~new(operation,self~name,self~version,algorithm,'BINARY64',16,'NumPy float64 ndarray',stack,'APPROXIMATE_IEEE754','NUMPY,BLAS,LAPACK,'algorithm))
  ev~addWarning('binary64 limits effective significance to about 16 decimal digits; any higher-precision source conversion is lossy and explicit via MathContext~binary64.')
  return ev
::method matrixAdd
  expose _np
  use strict arg left,right,context
  call rx_math_check_same_shape left,right
  la=self~_array(left); ra=self~_array(right)
  c=_np~add(la[1],ra[1]); rows=c~tolist
  ev=self~_evidence('matrix.add',context,.array~of(left~canonical,right~canonical),'numpy.add','ufunc elementwise addition')
  out=.MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.add',.array~of(left,right)),'NUMPY',c)
  if la[2] then la[1]~close; if ra[2] then ra[1]~close
  return out
::method matrixSub
  expose _np
  use strict arg left,right,context
  call rx_math_check_same_shape left,right
  la=self~_array(left); ra=self~_array(right)
  c=_np~subtract(la[1],ra[1]); rows=c~tolist
  ev=self~_evidence('matrix.sub',context,.array~of(left~canonical,right~canonical),'numpy.subtract','ufunc elementwise subtraction')
  out=.MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.sub',.array~of(left,right)),'NUMPY',c)
  if la[2] then la[1]~close; if ra[2] then ra[1]~close
  return out
::method matrixMul
  expose _np
  use strict arg left,right,context
  if right~isA(.MathMatrix) then do
    if left~cols<>right~rows then raise syntax 88.900 array('compatible matrix dimensions',left~cols'/'right~rows)
    la=self~_array(left); ra=self~_array(right); c=_np~matmul(la[1],ra[1]); rows=c~tolist
    ev=self~_evidence('matrix.matmul',context,.array~of(left~canonical,right~canonical),'numpy.matmul','NumPy dispatches matrix product through its configured native numerical stack')
    out=.MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.matmul',.array~of(left,right)),'NUMPY',c)
    if la[2] then la[1]~close; if ra[2] then ra[1]~close
    return out
  end
  return .Maths~provider('PURE')~matrixMul(left,right,context)
::method matrixTranspose
  use strict arg a,context
  aa=self~_array(a); c=aa[1]~get('T')
  rows=c~tolist
  ev=self~_evidence('matrix.transpose',context,.array~of(a~canonical),'numpy.ndarray.T','view/copy semantics remain provider-owned')
  out=.MathMatrix~new(rows,context,ev,.MathDerivation~new('matrix.transpose',.array~of(a)),'NUMPY',c)
  if aa[2] then aa[1]~close
  return out
::method matrixSolve
  expose _np
  use strict arg a,b,context
  if b~isA(.MathMatrix) then return .Maths~provider('PURE')~matrixSolve(a,b,context)
  aa=self~_array(a)
  kw=.ForeignPython~keywords; kw~put('dtype','float64')
  bb=_np~array(b~toArray,kw)
  linalg=_np~get('linalg'); x=linalg~solve(aa[1],bb); vals=x~tolist
  ev=self~_evidence('matrix.solve',context,.array~of(a~canonical,b~canonical),'numpy.linalg.solve','provider-selected LAPACK solve path; exact LAPACK routine depends on NumPy build')
  out=.MathVector~new(vals,context,ev,.MathDerivation~new('matrix.solve',.array~of(a,b)))
  ev~putCheck('residualInf',rx_math_residual_norm_inf(a,out,b,context))
  if aa[2] then aa[1]~close
  bb~close; x~close; linalg~close
  return out
::method uninit
  expose _np
  if symbol('_np')='VAR' then if _np \== .nil then _np~close

::requires 'MathsBootstrap.cls'
::requires 'python_foreign.cls'
