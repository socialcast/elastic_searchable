@echo off

SETLOCAL

if NOT DEFINED JAVA_HOME goto err

set SCRIPT_DIR=%~dp0
for %%I in ("%SCRIPT_DIR%..") do set ES_HOME=%%~dpfI


"%JAVA_HOME%\bin\java" -Xmx64m -Xms16m -Des.path.home="%ES_HOME%" -cp "%ES_HOME%/lib/*;" "org.elasticsearch.plugins.PluginManager" %*
goto finally


:err
echo JAVA_HOME environment variable must be set!
pause


:finally

ENDLOCAL
