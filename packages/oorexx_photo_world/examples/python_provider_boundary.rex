/* Architectural example only: requires Python Macrospace v0.31+ and its
 * runtime bootstrap.  The projected Python class/object remains authoritative.
 */
::requires '../rexx/SurveyForeignProviders.cls'
/*
cls = .AlchemyPythonClass~loadCls('photo_depth_provider', 'DepthProvider')
py = cls~new('depth-anything-v2')
depth = .SurveyPythonDepthProvider~new(py)
evidence = depth~infer('photo.jpg', 'sha256:...')
say evidence~kind evidence~provider
*/
