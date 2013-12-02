------------------------------------------------
-- Выполнение SQL запроса из командной строки --
------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_psql(text) RETURNS text AS $$
  my $sql = $_[0];

  # Инициализация глобальных переменных PLPerl
  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Выполнение psql на сервере БД
  my $stdout = `export PGPASSWORD=$_SHARED{'dbpass'}; echo "$sql" | psql -t -h localhost -p $_SHARED{'dbport'} -U $_SHARED{'dbuser'} $_SHARED{'dbname'}`;

  # Удаление лишних символов из вывода
  $stdout =~ s/[\r\n]+//g;
  substr $stdout, 0, 1, '';
  
  return $stdout;
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_psql(text) IS 'Выполнение SQL запроса из командной строки';

-----------------------------------------------------------------
-- Выполнение SQL запроса из командной строки в фоновом режиме --
-----------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_psqlb(text) RETURNS text AS $$
  my $sql = $_[0];

  # Инициализация глобальных переменных PLPerl
  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Выполнение psql на сервере БД
  my $stdout = `export PGPASSWORD=$_SHARED{'dbpass'}; echo "$sql" | psql -t -h localhost -p $_SHARED{'dbport'} -U $_SHARED{'dbuser'} $_SHARED{'dbname'} &`;

  # Удаление лишних символов из вывода
  $stdout =~ s/[\r\n]+//g;
  substr $stdout, 0, 1, '';
  
  return $stdout;
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_psqlb(text) IS 'Выполнение SQL запроса из командной строки в фоновом режиме';

---------------------------------------------
-- Выполнение команды на удаленном сервере --
---------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_ssh(text) RETURNS text AS $$
  my $cmd = $_[0];

  # Получаем адрес удаленного сервера
  my $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'grasshost'");
  my $grasshost = $rv->{rows}[0]->{value};

  # Сохранение двойных кавычек в тексте команды
  $cmd =~ s/"/\\"/g;

  # Выполнение команды на удаленном сервере
  my $stdout = `ssh tomcat\@$grasshost "$cmd"`;
  
  return $stdout;
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_ssh(text) IS 'Выполнение команды на удаленном сервере';

------------------------------------------------------------------------------
-- Выполнение команды на удаленном сервере с инициализацией GRASS окружения --
------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_ssh(text, text) RETURNS text AS $$
  my $resourceid = $_[0];
  my $cmd        = $_[1];

  # Конвертация строки в нижний регистр и замена символа "-" на "_"
  $resourceid =~ s/-/_/;
  $resourceid = lc($resourceid);

  # Сохранение двойных кавычек в тексте команды
  $cmd =~ s/"/\\"/g;

  # Получаем переменные GRASS из настроечной таблицы
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'grasshome'");
  my $grasshome = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'ovhome'");
  my $ovhome = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'grasshost'");
  my $grasshost = $rv->{rows}[0]->{value};

  # Формирование переменных GRASS окружения
  $env = "export GISBASE=$grasshome;";
  $env = $env . "export GISRC=$ovhome/var/grassrc/.$resourceid;";
  $env = $env . "export LD_LIBRARY_PATH=$grasshome/lib;";
  $env = $env . "export PATH=/usr/local/bin:/bin:/usr/bin:$grasshome/bin:$grasshome/scripts;";
  $env = $env . "export LANG=en_US.UTF-8;";

  # Инициализация MAPSET
  $rcexist = `ssh tomcat\@$grasshost "if [ -f $ovhome/var/grassrc/.$resourceid ]; then echo -n 1; else echo -n 0; fi"`;
  if ($rcexist eq '0') {
    `ssh tomcat\@$grasshost "$env g.gisenv set='GISDBASE=$ovhome/var/grasswp'"`;
    `ssh tomcat\@$grasshost "$env g.gisenv set='LOCATION_NAME=ESIMO'"`;
    `ssh tomcat\@$grasshost "$env g.gisenv set='MAPSET=$resourceid'"`;
    `ssh tomcat\@$grasshost "$env g.gisenv set='GRASS_GUI=text'"`;
  }

  # Инициализация WORKSPACE
  $wpexist = `ssh tomcat\@$grasshost "if [ -d $ovhome/var/grasswp/ESIMO/$resourceid ]; then echo -n 1; else echo -n 0; fi"`;
  if ($wpexist eq '0') {
    `ssh tomcat\@$grasshost "$env cp -a $ovhome/var/grasswp/ESIMO/NEW $ovhome/var/grasswp/ESIMO/$resourceid"`;
  }

  # Логирование текста команды в файл
  `ssh tomcat\@$grasshost "echo -e '\n[\`date '+%F %H:%M'\`] SSH: $cmd' >> $_SHARED{'logpath'}/$resourceid.log"`;
  
  # Выполнение команды на удаленном сервере с инициализацией GRASS окружения
  $stdout = `ssh tomcat\@$grasshost "$env $cmd >> $_SHARED{'logpath'}/$resourceid.log 2>&1"`;

  return $stdout;
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_ssh(text, text) IS 'Выполнение команды на удаленном сервере с инициализацией GRASS окружения';

------------------------------------------------
-- Инициализация глобальных переменных PLPerl --
------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_initPLPerl() RETURNS text AS $$
  # Инициализация глобальных переменных из настроечной таблицы
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'ovhome'");
  $_SHARED{'ovhome'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'geoserver'");
  $_SHARED{'geoserver'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'grasshome'");
  $_SHARED{'grasshome'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'grasshost'");
  $_SHARED{'grasshost'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'gsuser'");
  $_SHARED{'gsuser'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'gspass'");
  $_SHARED{'gspass'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'gsnodes'");
  $_SHARED{'gsnodes'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'maxproc'");
  $_SHARED{'maxproc'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'nodeid'");
  $_SHARED{'nodeid'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'version'");
  $_SHARED{'version'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'authurl'");
  $_SHARED{'authurl'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'dbhost'");
  $_SHARED{'dbhost'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'dbport'");
  $_SHARED{'dbport'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'dbname'");
  $_SHARED{'dbname'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'dbuser'");
  $_SHARED{'dbuser'} = $rv->{rows}[0]->{value};
  $rv = spi_exec_query("SELECT value FROM admin.config_table WHERE key = 'dbpass'");
  $_SHARED{'dbpass'} = $rv->{rows}[0]->{value};

  # Формирование структуры папок
  $_SHARED{'imgpath'} = "$_SHARED{'ovhome'}/data/resources/surfaces";
  $_SHARED{'mskpath'} = "$_SHARED{'ovhome'}/data/resources/mask";
  $_SHARED{'sqlpath'} = "$_SHARED{'ovhome'}/data/resources/sql";
  $_SHARED{'xlspath'} = "$_SHARED{'ovhome'}/data/resources/xls";
  $_SHARED{'logpath'} = "$_SHARED{'ovhome'}/log/resources";
  $_SHARED{'jarpath'} = "$_SHARED{'ovhome'}/lib";
  $_SHARED{'grasswp'} = "$_SHARED{'ovhome'}/var/grasswp";
  $_SHARED{'grassrc'} = "$_SHARED{'ovhome'}/var/grassrc";
  $_SHARED{'cookies'} = "$_SHARED{'ovhome'}/var/cookies";
  $_SHARED{'location'} = "ESIMO";

  if ($_SHARED{'version'} ne '') {
    return 'ok';
  }
  else {
    return 'error';
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_initPLPerl() IS 'Инициализация глобальных переменных PLPerl';

-------------------------
-- Авторизация в JOSSO --
-------------------------
CREATE OR REPLACE FUNCTION admin.ov_loginJOSSO(text) RETURNS text AS $$
  my $processid = $_[0] ne '' ? $_[0] : time;

  # Инициализация глобальных переменных PLPerl
  #if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  #}

  # Есть ли доступ к геосерверу?
  $response = `curl --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/`;
  if ($response ne '200') {
    # Если нет, авторизуемся в JOSSO и получаем cookies для геосервера
    `curl --location-trusted -s -o /dev/null -w "%{http_code}" -c /tmp/josso.txt -d "josso_cmd=login&josso_back_to=&josso_username=$_SHARED{'gsuser'}&josso_password=$_SHARED{'gspass'}" $_SHARED{'authurl'}/login.do`;
    `curl --location-trusted -s -o /dev/null -w "%{http_code}" -c /tmp/geoserver.txt -b /tmp/josso.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/web/`;

    # Еще раз проверяем доступ к геосерверу
    $response = `curl --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/`;
    if ($response eq '200') {
      spi_exec_query("SELECT admin.ov_logEvent('$processid', NULL, NULL, NULL, 'loginJOSSO', '".time."', '".time."', 'INFO', 'Authorization ok')");
      return 'Authorization ok';
    }
    else {
      spi_exec_query("SELECT admin.ov_logEvent('$processid', NULL, NULL, NULL, 'loginJOSSO', '".time."', '".time."', 'ERROR', 'Authorization error, with code $response')");
      return "Authorization error, with code $response";
    }
  }
  else {
    return 'Already authorized';
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_loginJOSSO(text) IS 'Авторизация в JOSSO';

----------------------------
-- Деавторизация из JOSSO --
----------------------------
CREATE OR REPLACE FUNCTION admin.ov_logoutJOSSO() RETURNS text AS $$
`rm /tmp/josso.txt`;
`rm /tmp/geoserver.txt`;
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_logoutJOSSO() IS 'Деавторизация из JOSSO';

---------------------------------
-- Проверка существования слоя --
---------------------------------
CREATE OR REPLACE FUNCTION admin.ov_isLayerExists(text, text, text) RETURNS boolean AS $$
  my $processid = $_[0] ne '' ? $_[0] : time;
  my $workspace = $_[1];
  my $layername = $_[2];

  # Инициализация глобальных переменных PLPerl
  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Авторизация в JOSSO
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");
  
  # Существует ли слой?
  $response = `curl --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/layers/$workspace\:$layername`;
  if ($response eq '200') {
    return true;
  }
  else {
    return false;
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_isLayerExists(text, text, text) IS 'Проверка существования слоя';

------------------------------------
-- Проверка существования таблицы --
------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_isTableExists(tablename text, schema text) RETURNS boolean AS $$
DECLARE
  result text;
BEGIN
  EXECUTE 'SELECT table_name FROM information_schema.columns WHERE table_name = ''' || tablename || ''' AND table_schema = ''' || schema || '''' INTO result;
  IF result IS NOT NULL THEN
    RETURN true;
  ELSE 
    RETURN false;
  END IF;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_isTableExists(text, text) IS 'Проверка существования таблицы';

---------------------------------------------------------------------
-- Конвертация строки в нижний регистр и замена символа "-" на "_" --
---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_lcc(text) RETURNS text AS $$
BEGIN
  RETURN lower(replace($1, '-', '_'));
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_lcc(text) IS 'Конвертация строки в нижний регистр и замена символа "-" на "_"';

------------------------------
-- Получение заголовка слоя --
------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayerTitle(resourceid text, param text, type text) RETURNS text AS $$
DECLARE
  title text;
  date text;
  schema text;
  tablename text;
BEGIN
--  -- Получение схемы хранения ресурса в БД
--  EXECUTE 'SELECT admin.ov_getSchema(''' || resourceid || ''')' INTO schema;

--  -- Получаем имя таблицы для ресурса в БД
--  EXECUTE 'SELECT admin.ov_lcc(''' || resourceid || ''')' INTO tablename;

--  -- Получение даты ресурса
--  EXECUTE 'SELECT m4400 FROM ' || schema || '.' || tablename || ' LIMIT 1' INTO date;
--  IF date IS NULL THEN
--    RAISE EXCEPTION 'Can''t get field m4400 from tablename = %', tablename;
--  END IF;

--  -- Получение поля title из таблицы admin_table
--  IF "type" = 'pt' THEN
--    EXECUTE 'SELECT title FROM admin.admin_table WHERE resourceid = ''' || resourceid || 
--            ''' AND type = ''' || "type" || '''' INTO title;
--  ELSE
--    EXECUTE 'SELECT title FROM admin.admin_table WHERE resourceid = ''' || resourceid || 
--           ''' AND param = ''' || param || ''' AND type = ''' || "type" || '''' INTO title;
--  END IF;
--  IF title IS NULL THEN
--    RAISE EXCEPTION 'Can''t get title';
--  END IF;

--  SELECT replace(title, '<DATE>', date) INTO title;

  -- Договоренность использовать предоставленную функцию
  SELECT GetLayerName(resourceid, param, "type") INTO title;
  
  RETURN title;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getLayerTitle(text, text, text) IS 'Получение заголовка слоя';

--------------------------------
-- Получение описания ресурса --
--------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getResourceDescription(resourceid text) RETURNS text AS $$
DECLARE
  description text;
BEGIN
  -- Получение поля objectdescription из таблицы resource_md
  EXECUTE 'SELECT objectdescription FROM resource_md WHERE resourceid ilike ''' || resourceid || '''' INTO description;
  IF description IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''0'', ''' || resourceid || ''', NULL, NULL, ''getResourceDescription'', ''' || round(extract(epoch FROM now())) || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Cant get description for resourceid ' || resourceid || ''')';
--    RAISE EXCEPTION 'Can''t get description for resourceid = %', resourceid;
  END IF;

  RETURN description;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getResourceDescription(text) IS 'Получение описания ресурса';

---------------------------------
-- Получение workspace ресурса --
---------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getWorkspace(processid text, resourceid text) RETURNS text AS $$
DECLARE
  workspace text;
BEGIN
  -- Получение поля primaryresourceid из таблицы resource_md
  --EXECUTE 'SELECT primaryresourceid FROM resource_md WHERE resourceid ilike ''' || resourceid || '''' INTO workspace;
  EXECUTE 'SELECT workspace FROM admin.admin_table WHERE resourceid ilike ''' || resourceid || ''' LIMIT 1' INTO workspace;
  IF workspace IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''getWorkspace'', ''' || round(extract(epoch FROM now())) || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Cant get workspace for resourceid ' || resourceid || ''')';
  END IF;

  RETURN workspace;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getWorkspace(text, text) IS 'Получение workspace ресурса';

-----------------------------
-- Формирование имени слоя --
-----------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayername(resourceid text, param text, type text) RETURNS text AS $$
DECLARE
  layername text;
  str text;
BEGIN
  -- Если слой точечный, то откидываем param и type
  IF "type" = 'pt' THEN
    str = resourceid;
  ELSE
    str = resourceid || '_' || param || '_' || "type";
  END IF;

  -- Конвертация в нижний регистр и замена символа "-" на "_"
  EXECUTE 'SELECT admin.ov_lcc(''' || str || ''')' INTO layername;
  IF layername IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''0'', ''' || resourceid || ''', NULL, NULL, ''getLayername'', ''' || round(extract(epoch FROM now())) || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Layername is empty'')';
--    RAISE EXCEPTION 'Layername is empty';
  END IF;

  RETURN layername;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getLayername(text, text, text) IS 'Формирование имени слоя';

--------------------------------------------
-- Получение схемы хранения ресурса в БИД --
--------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getSchema(processid text, resourceid text) RETURNS text AS $$
DECLARE
  schema text;
BEGIN
  EXECUTE 'SELECT scheme FROM resource_md WHERE resourceid ilike ''' || resourceid || '''' INTO schema;
  IF schema IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''getSchema'', ''' || round(extract(epoch FROM now())) || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Cant get DB schema for resourceid ' || resourceid || ' from table ''resource_md'''')';
--    RAISE EXCEPTION 'Can''t get DB schema for resourceid = %', resourceid;
    RETURN 'public';
  END IF;

  RETURN schema;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getSchema(text, text) IS 'Получение схемы хранения ресурса в БИД';

-----------------------------------------------
-- Получение стиля назначенного по умолчанию --
-----------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayerDefaultStyle(resourceid text, param text, type text) RETURNS text AS $$
DECLARE
  defaultstyle text = '';
BEGIN
  -- Получение поля defaultstyle из таблицы admin_table
  IF "type" = 'pt' THEN
    EXECUTE 'SELECT defaultstyle FROM admin.admin_table WHERE resourceid ilike ''' || resourceid || 
            ''' AND type = ''' || "type" || '''' INTO defaultstyle;
  ELSE
    EXECUTE 'SELECT defaultstyle FROM admin.admin_table WHERE resourceid ilike ''' || resourceid || 
            ''' AND param = ''' || param || ''' AND type = ''' || "type" || '''' INTO defaultstyle;
  END IF;
  IF defaultstyle IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''0'', ''' || resourceid || ''', NULL, NULL, ''getLayerDefaultStyle'', ''' || round(extract(epoch FROM now())) || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Cant get default style'')';
--    RAISE EXCEPTION 'Can''t get default style';
  END IF;

  RETURN defaultstyle;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getLayerDefaultStyle(text, text, text) IS 'Получение стиля назначенного по умолчанию';

-----------------------------------------------------
-- Получение стилей назначенных слою в виде строки --
-----------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayerStyles(resourceid text, param text, type text) RETURNS text AS $$
DECLARE
  styles text = '';
BEGIN
  -- Получение поля styles из таблицы admin_table
  IF "type" = 'pt' THEN
    EXECUTE 'SELECT styles FROM admin.admin_table WHERE resourceid = ''' || resourceid || 
            ''' AND type = ''' || "type" || '''' INTO styles;
  ELSE
    EXECUTE 'SELECT styles FROM admin.admin_table WHERE resourceid = ''' || resourceid || 
            ''' AND param = ''' || param || ''' AND type = ''' || "type" || '''' INTO styles;
  END IF;
  IF styles IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''0'', ''' || resourceid || ''', NULL, NULL, ''getLayerStyles'', ''' || round(extract(epoch FROM now())) || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Cant get styles'')';
--    RAISE EXCEPTION 'Can''t get styles';
  END IF;

  RETURN styles;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getLayerStyles(text, text, text) IS 'Получение стилей назначенных слою в виде строки';

--------------------------------------------------
-- Получение стилей назначенных слою в виде XML --
--------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayerStylesXML(resourceid text, param text, type text) RETURNS text AS $$
DECLARE
  styles text = '';
  s text;
  xml text = '<styles>';
BEGIN
  -- Получение поля styles из таблицы admin_table
  SELECT admin.ov_getLayerStyles(resourceid, param, "type") INTO styles;

  -- Разбиение и генерация XML 
  FOR s IN SELECT unnest(regexp_split_to_array(styles, ',')) LOOP
    xml := xml || '<style>' || s || '</style>';
  END LOOP;

  RETURN xml || '</styles>';
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getLayerStylesXML(text, text, text) IS 'Получение стилей назначенных слою в виде XML';

-------------------------------------------
-- Получение ключевых слов в виде строки --
-------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayerKeywords(resourceid text) RETURNS text AS $$
DECLARE
  keywords text = '';
  elements text = '';
  primaryresourceid text = '';
  begindatetime text = '';
  enddatetime text = '';
  temporalresolution text = '';
  verticalresolution text = '';
  result text = '';
BEGIN
  -- Получение списка ключевых слов
  SELECT getResourceElementSetAsStr(resourceid) INTO elements;
  SELECT regexp_replace(elements, ',?id,?', '') INTO elements;
  SELECT regexp_replace(elements, '([^,]+)', E'element#\\1', 'g') INTO elements;
  IF elements IS NOT NULL THEN
    result = elements;
  END IF;

  EXECUTE 'SELECT primaryresourceid FROM resource_md WHERE resourceid ilike ''' || resourceid || '''' INTO primaryresourceid;
  IF primaryresourceid IS NOT NULL THEN
    EXECUTE 'SELECT array_to_string(array(' ||
            'select descriptivekeywords from resource_descriptive_keywords where irid in' ||
            '(select irid from resource_md where resourceid ilike ''' || primaryresourceid || ''')' ||
            '), '','')' INTO keywords;
    SELECT regexp_replace(keywords, '([^,]+)', E'desc#\\1', 'g') INTO keywords;
  END IF;
  IF keywords IS NOT NULL THEN
    result = result || keywords;
  END IF;
  
  EXECUTE 'SELECT begindatetime FROM resource_md WHERE resourceid ilike ''' || resourceid || '''' INTO begindatetime;
  EXECUTE 'SELECT enddatetime FROM resource_md WHERE resourceid ilike ''' || resourceid || '''' INTO enddatetime;
  EXECUTE 'SELECT temporalresolution FROM resource_md WHERE resourceid ilike ''' || resourceid || '''' INTO temporalresolution;
  EXECUTE 'SELECT verticalresolution FROM resource_md WHERE resourceid ilike ''' || resourceid || '''' INTO verticalresolution;
  
  result = result || 
           'begindatetime#' || coalesce(begindatetime, '') || ',' ||
           'enddatetime#' || coalesce(enddatetime, '') || ',' ||
           'temporalresolution#' || coalesce(temporalresolution, '') || ',' ||
           'verticalresolution#' || coalesce(verticalresolution, '');
  RETURN result;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getLayerKeywords(text) IS 'Получение ключевых слов в виде строки';

----------------------------------------
-- Получение ключевых слов в виде XML --
----------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayerKeywordsXML(resourceid text) RETURNS text AS $$
DECLARE
  keywords text = '';
  s text;
  xml text = '<keywords>';
BEGIN
  -- Получение ключевых слов в виде строки
  SELECT admin.ov_getLayerKeywords(resourceid) INTO keywords;

  -- Разбиение и генерация XML 
  FOR s IN SELECT unnest(regexp_split_to_array(keywords, ',')) LOOP
    xml := xml || '<string>' || s || '</string>';
  END LOOP;

  RETURN xml || '</keywords>';
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getLayerKeywordsXML(text) IS 'Получение ключевых слов в виде XML';

-------------------------------------------------------
-- Получение пространственных границ слоя в виде XML --
-------------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayerBBoxXML(processid text, resourceid text) RETURNS text AS $$
DECLARE
  minx text;
  miny text;
  maxx text;
  maxy text;
  m1253 text;
  schema text;
  tablename text;
BEGIN
  -- Получение схемы хранения ресурса в БД
  EXECUTE 'SELECT admin.ov_getSchema(''' || processid || ''', ''' || resourceid || ''')' INTO schema;

  -- Получаем имя таблицы для ресурса в БД
  EXECUTE 'SELECT admin.ov_lcc(''' || resourceid || ''')' INTO tablename;

  -- Проверяем наличие колонки геометрии
  EXECUTE 'SELECT column_name FROM information_schema.columns WHERE table_name=''' || tablename || ''' AND table_schema = ''' || schema || ''' AND column_name=''m1253''' INTO m1253;
  IF m1253 IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''0'', ''' || resourceid || ''', NULL, NULL, ''getLayerBBoxXML'', ''' || round(extract(epoch FROM now())) || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''No coordinate columns for table ' || tablename || ''')';
--    RAISE EXCEPTION 'No coordinate columns for table = %', tablename;
  END IF;
  
  -- Получение пространственных границ ресурса
  EXECUTE 'SELECT ST_XMin(ST_Extent(m1253)) FROM ' || schema || '.' || tablename INTO minx;
  EXECUTE 'SELECT ST_YMin(ST_Extent(m1253)) FROM ' || schema || '.' || tablename INTO miny;
  EXECUTE 'SELECT ST_XMax(ST_Extent(m1253)) FROM ' || schema || '.' || tablename INTO maxx;
  EXECUTE 'SELECT ST_YMax(ST_Extent(m1253)) FROM ' || schema || '.' || tablename INTO maxy;

  -- Формируем XML
  IF (minx IS NULL) OR (miny IS NULL) OR (maxx IS NULL) OR (maxy IS NULL) THEN
    RETURN '<minx>-180</minx><miny>-90</miny><maxx>180</maxx><maxy>90</maxy>';
  ELSE
    RETURN '<minx>' || minx || '</minx><miny>' || miny || '</miny><maxx>' || maxx || '</maxx><maxy>' || maxy || '</maxy>';
  END IF;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_getLayerBBoxXML(text, text) IS 'Получение пространственных границ слоя в виде XML';

----------------------------------------------------
-- Получение информации о сетке растра в виде XML --
----------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_getLayerGridXML(text) RETURNS text AS $$
  my $pathtofile  = $_[0];
  my ($range, $scale, $translate);

  # Запускаем команду gdalinfo для растра
  my $rv = spi_exec_query("SELECT admin.ov_ssh('gdalinfo $pathtofile')");
  my $stdout = $rv->{rows}[0]->{ov_ssh};

  # Парсим вывод команды gdalinfo
  if ( $stdout =~ /Size is (\d+), (\d+)/g ) {
    $range = "<high>$1 $2</high>";
  }
  if ( $stdout =~ /Origin = \(([\d\.\-]+),([\d\.\-]+)\)/g ) {
    $translate = "<translateX>$1</translateX><translateY>$2</translateY>";
  }
  if ( $stdout =~ /Pixel Size = \(([\d\.\-]+),([\d\.\-]+)\)/g ) {
    $scale = "<scaleX>$1</scaleX><scaleY>$2</scaleY>";
  }

  # Формируем XML
  my $xml = "<range><low>0 0</low>" .
              $range .
            "</range><transform>" .
              $scale .
            "<shearX>0.0</shearX><shearY>0.0</shearY>" .
              $translate .
            "</transform><crs>EPSG:4326</crs>";

  return $xml;
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_getLayerGridXML(text) IS 'Получение информации о сетке растра в виде XML';

-------------------------------------------
-- Обновление title в сохраненных картах --
-------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_updateLayerTitleInSavedMaps(resourceid text, param text, type text) RETURNS text AS $$
DECLARE
  title text;
  rowcount int;
  layername text;
BEGIN
  -- Получение заголовка слоя
  SELECT admin.ov_getLayerTitle(resourceid, param, "type") INTO title;

  -- Получение наименования слоя
  SELECT admin.ov_getLayername(resourceid, param, "type") INTO layername;

  -- Замена части json в сохраненных картах 
  UPDATE admin.savedmaps SET config = regexp_replace(config, '"name":"(.+):' || layername || 
	'","title":".+"', E'"name":"\\1:' || layername || '","title":"' || title || '"', 'g');

  -- Возвращаем количество обработанных карт
  GET DIAGNOSTICS rowcount = ROW_COUNT;
  RETURN coalesce(rowcount, 0) || ' savedmaps were updated';
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_updateLayerTitleInSavedMaps(text, text, text) IS 'Обновление поля title в сохраненных картах';

---------------------------------------------
-- Добавление ресурса в очередь обработки  --
---------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_pushInQueue(processid text, resourceid text, param text, type text) RETURNS text AS $$
DECLARE 
  procinqueue int;
  maxproc int;
  sameprocess text;
  sameresource text;
BEGIN
  -- Проверяем есть ли такой процесс в очереди
  EXECUTE 'SELECT processid FROM admin.process_queue WHERE processid ilike ''' || processid ||'''' INTO sameprocess;
  -- Если это тот же самый процесс, то ничего не делаем
  IF sameprocess IS NOT NULL THEN
    RETURN 'Nothing to do. It''s the same process.';
  ELSE
    -- Проверяем есть ли такой ресурс в очереди
    IF "type" = 'pt' THEN
      EXECUTE 'SELECT resourceid FROM admin.process_queue WHERE resourceid ilike ''' || resourceid || ''' AND type ilike ''' || "type" || '''' INTO sameresource;
    ELSE
      EXECUTE 'SELECT resourceid FROM admin.process_queue WHERE resourceid ilike ''' || resourceid || ''' AND param ilike ''' || param || ''' AND type ilike ''' || "type" || '''' INTO sameresource;
    END IF;
    -- Если процесс новый, но ресурс уже в обработке, то ждем и пробуем заново
    IF sameresource IS NOT NULL THEN
      PERFORM pg_sleep(30);
      RETURN admin.ov_pushInQueue(processid, resourceid, param, "type");
      --RAISE EXCEPTION 'Resource already in the queue';
    ELSE
      -- Если процесс новый и ресурс не обрабатывается, то ставим в очередь
      -- Получаем количество запущенных процессов
      EXECUTE 'SELECT DISTINCT ON (processid) processid FROM admin.process_queue';
      GET DIAGNOSTICS procinqueue = ROW_COUNT;
      -- Получаем количество ядер процессора
      SELECT value FROM admin.config_table WHERE key = 'maxproc' INTO maxproc;

      -- Если запущенных процесов меньше чем количество ядер, то ставим в очередь
      IF procinqueue <= maxproc THEN
        EXECUTE 'INSERT INTO admin.process_queue (processid, resourceid, param, type) VALUES (''' || processid || ''', ''' || resourceid || ''', ''' || param || ''', ''' || "type" || ''')';
        RETURN 'Resource ' || resourceid || ' pushed in the queue';
      ELSE
        -- иначе ждем и пробуем заново
        PERFORM pg_sleep(30);
        RETURN admin.ov_pushInQueue(processid, resourceid, param, "type");
      END IF;
    END IF;
  END IF;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_pushInQueue(text, text, text, text) IS 'Добавление ресурса в очередь обработки';

--------------------------------------------
-- Удаление ресурса из очереди обработки  --
--------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_popFromQueue(processid text, resourceid text, param text, type text) RETURNS text AS $$
DECLARE
  rowcount int;
BEGIN
  EXECUTE 'DELETE FROM admin.process_queue WHERE processid ilike ''' || processid || ''' AND resourceid ilike ''' || resourceid || ''' AND param ilike ''' || param || ''' AND type ilike ''' || "type" || '''';
  GET DIAGNOSTICS rowcount = ROW_COUNT;
  IF rowcount <> 0 THEN
    RETURN 'Process #' || processid || ' was deleted from the queue';
  ELSE
    RETURN 'Process wasnt deleted from the queue';
  END IF;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_popFromQueue(text, text, text, text) IS 'Удаление ресурса из очереди обработки';

--------------------------------------------------------------
-- Добавление колонки геометрии в таблицу точечного ресурса --
--------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_addGeometryColumn(processid text, resourceid text) RETURNS text AS $$
DECLARE
  schema text;
  tablename text;
  m4312 text;
  m4311 text;
  m1253 text;
  stageStartTime int;
BEGIN
  -- Засекаем время запуска функции
  EXECUTE 'SELECT round(extract(epoch FROM now()))' INTO stageStartTime;

  -- Получаем имя таблицы для ресурса в БД
  EXECUTE 'SELECT admin.ov_lcc(''' || resourceid || ''')' INTO tablename;

  -- Получение схемы хранения ресурса в БД
  EXECUTE 'SELECT admin.ov_getSchema(''' || processid || ''', ''' || resourceid || ''')' INTO schema;
  IF schema IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addGeometryColumn'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Cant get DB schema for resourceid ' || resourceid || ''')';
    RETURN 'Cant get DB schema for resourceid ' || resourceid;
  END IF;
    
  -- Проверка существует ли колонка с геометрией?
  -- EXECUTE 'SELECT DropGeometryColumn(''' || schema || ''',''' || tablename || ''',''m1253'')';
  EXECUTE 'SELECT column_name FROM information_schema.columns WHERE table_name=''' || tablename || 
          ''' AND table_schema=''' || schema || ''' AND column_name=''m1253''' INTO m1253;
  IF m1253 IS NULL THEN
    -- Проверяем наличие координат
    EXECUTE 'SELECT m4312 FROM ' || schema || '.' || tablename || ' LIMIT 1' INTO m4312;
    EXECUTE 'SELECT m4311 FROM ' || schema || '.' || tablename || ' LIMIT 1' INTO m4311;
    IF m4312 IS NULL OR m4311 IS NULL THEN
      EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addGeometryColumn'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''No coordinate columns for table ' || tablename || ''')';
--      RAISE EXCEPTION 'No coordinate columns for table = %', tablename;
    END IF;
  
    -- Удаление строк с пыстыми координатами
    EXECUTE 'DELETE FROM ' || schema || '.' || tablename || ' WHERE m4312 is NULL OR m4311 is NULL';

    -- Скопировать точки с долготой 180 в точки с долготой -180 (*openlayers bug*)
    EXECUTE 'CREATE TABLE ' || schema || '.' || tablename || '_tmp180 AS SELECT * FROM ' || schema || '.' || tablename || ' WHERE m4312 = 180';
    EXECUTE 'UPDATE ' || schema || '.' || tablename || '_tmp180 SET m4312 = m4312 * -1';
    EXECUTE 'INSERT INTO ' || schema || '.' || tablename || ' SELECT * FROM ' || schema || '.' || tablename || '_tmp180';
    EXECUTE 'DROP TABLE IF EXISTS ' || schema || '.' || tablename || '_tmp180 CASCADE';

    -- Нормирование долготы
    EXECUTE 'UPDATE ' || schema || '.' || tablename || ' SET m4312 = m4312-360 WHERE m4312 > 180';

    -- Создание геометрии  
    EXECUTE 'SELECT AddGeometryColumn(''' || schema || ''',''' || tablename || ''',''m1253'',4326,''POINT'',2)';
    EXECUTE 'SELECT Populate_Geometry_Columns(''' || schema || '.' || tablename || '''::regclass)';
    EXECUTE 'UPDATE ' || schema || '.' || tablename || ' SET m1253 = ST_SetSRID(ST_MakePoint(m4312,m4311), 4326)';
 
   -- Создание пространственного индекса
    EXECUTE 'DROP INDEX IF EXISTS ' || schema || '.' || tablename || '_m1253_idx';
    EXECUTE 'CREATE INDEX ' || tablename || '_m1253_idx ON ' || schema || '.' || tablename || ' USING gist(m1253)';
    EXECUTE 'CLUSTER ' || tablename || '_m1253_idx ON ' || schema || '.' || tablename;
    
    -- Итоговая проверка
    EXECUTE 'SELECT m1253 FROM ' || schema || '.' || tablename || ' LIMIT 1' INTO m1253;
    IF m1253 IS NULL THEN
      EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addGeometryColumn'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Failed to create geometry column for table ' || tablename || ''')';
      --RAISE EXCEPTION 'Failed to create geometry column for table = %', tablename;
      RETURN 'Failed to create geometry column for table = ' || tablename;
    ELSE
      EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addGeometryColumn'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''INFO'', ''Geometry column created successfully'')';
      RETURN 'Geometry column created successfully';
    END IF;
  ELSE
    EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addGeometryColumn'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''INFO'', ''Geometry column already exists'')';
    RETURN 'Geometry column already exists';
  END IF;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_addGeometryColumn(text, text) IS 'Добавление колонки геометрии в таблицу точечного ресурса';

---------------------------------------------------
-- Добавление первичного ключа в таблицу точечного ресурса --
---------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_addPrimaryKey(processid text, resourceid text) RETURNS text AS $$
DECLARE
  schema text;
  tablename text;
  pk_exist text;
  stageStartTime int;
BEGIN
  -- Засекаем время запуска функции
  EXECUTE 'SELECT round(extract(epoch FROM now()))' INTO stageStartTime;
  
  -- Получаем имя таблицы для ресурса в БД
  EXECUTE 'SELECT admin.ov_lcc(''' || resourceid || ''')' INTO tablename;

  -- Получение схемы хранения ресурса в БД
  EXECUTE 'SELECT admin.ov_getSchema(''' || processid || ''', ''' || resourceid || ''')' INTO schema;
  IF schema IS NULL THEN
    EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addGeometryColumn'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Cant get DB schema for resourceid ' || resourceid || ''')';
    RETURN 'Cant get DB schema for resourceid ' || resourceid;
  END IF;

  -- Проверка существует ли колонка с первичным ключом?
  EXECUTE 'SELECT column_name FROM information_schema.columns WHERE table_name=''' || tablename || 
          ''' AND table_schema=''' || schema || ''' AND column_name=''m1232''' INTO pk_exist;
  IF pk_exist IS NULL THEN
    -- Создание первичного ключа
    EXECUTE 'ALTER TABLE ' || schema || '.' || tablename || ' ADD COLUMN m1232 serial NOT NULL';
    EXECUTE 'ALTER TABLE ' || schema || '.' || tablename || ' ADD CONSTRAINT ' || tablename || '_pk PRIMARY KEY(m1232)';

    -- Итоговая проверка
    EXECUTE 'SELECT m1232 FROM ' || schema || '.' || tablename || ' LIMIT 1' INTO pk_exist;
    IF pk_exist IS NULL THEN
      EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addPrimaryKey'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''ERROR'', ''Failed to create Primary Key'')';
      --RAISE EXCEPTION 'Problem with creation primary key for table = %', tablename;
      RETURN 'Failed to create Primary Key';
    ELSE
      EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addPrimaryKey'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''INFO'', ''Primary Key created successfully'')';
      RETURN 'Primary Key created successfully';
    END IF;
  ELSE
    EXECUTE 'SELECT admin.ov_logEvent(''' || processid || ''', ''' || resourceid || ''', NULL, NULL, ''addPrimaryKey'', ''' || stageStartTime || ''', ''' || round(extract(epoch FROM now())) || ''', ''INFO'', ''Primary Key already exists'')';
    RETURN 'Primary Key already exists';
  END IF;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_addPrimaryKey(text, text) IS 'Добавление первичного ключа в таблицу точечного ресурса';

-------------------
-- Удаление слоя --
-------------------
CREATE OR REPLACE FUNCTION admin.ov_removeLayer(text, text, text) RETURNS text AS $$
  my $processid = $_[0] ne '' ? $_[0] : time;
  my $workspace = $_[1];
  my $layername = $_[2];
  my $stageStartTime = time;
  
  # Инициализация глобальных переменных PLPerl
  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Авторизация в JOSSO
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");

  # Удаление PostGIS слоя
  if ($layername =~ /[\d+|ln|tr|pl]$/) {
    $response1 = `curl -XDELETE --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/layers/$workspace\:$layername`;
    $response2 = `curl -XDELETE --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/workspaces/$workspace/datastores/bid/featuretypes/$layername`;
  }
  # Удаление GeoTIFF слоя
  elsif ($layername =~ /sf$/) {
    $response1 = `curl -XDELETE --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/layers/$workspace\:$layername`;
    $response2 = `curl -XDELETE --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/workspaces/$workspace/coveragestores/$layername/coverages/$layername`;
    $response3 = `curl -XDELETE --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/workspaces/$workspace/coveragestores/$layername`;
  }

  # Перезагрузка каталога геосервера
#  spi_exec_query("SELECT admin.ov_reloadGeoserverNodes('$processid')");

  if ($response1 eq '200') {
    return "Layer $layername was successfully removed";
  }
  else {
    return "Failed to remove layer $layername with code $response1";
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_removeLayer(text, text, text) IS 'Удаление слоя';

------------------------
-- Создание workspace --
------------------------
CREATE OR REPLACE FUNCTION admin.ov_createWorkspace(text, text) RETURNS text AS $$
  my $processid = $_[0] ne '' ? $_[0] : time;
  my $workspace = $_[1];
  
  # Инициализация глобальных переменных PLPerl
  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Авторизация в JOSSO
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");

  if ($workspace eq '') {
      spi_exec_query("SELECT admin.ov_logEvent('$processid', NULL, NULL, NULL, 'createWorkspace', '".time."', '".time."', 'ERROR', 'Input argument is empty')");
      return "Input argument is empty";    
  }

  # Проверяем существует ли такой workspace
  my $cmd = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " .
            "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
            "$_SHARED{'geoserver'}/rest/workspaces/$workspace";
  my $response = qx($cmd);

  if ($response eq '200') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'createWorkspace', '".time."', '".time."', 'INFO', 'Workspace $workspace already exists')");
    return "Workspace $workspace already exists";
  }
  else {
    # Создаем workspace
    $cmd1 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " .
            "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
            "-XPOST -H 'Content-type: application/xml' " .
            "-d '<workspace><name>$workspace</name></workspace>' " . 
            "$_SHARED{'geoserver'}/rest/workspaces";

    # Создаем namespace
    $cmd2 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " .
            "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
            "-XPUT -H 'Content-type: application/xml' " .
            "-d '<namespace><prefix>$workspace</prefix><uri>$workspace</uri></namespace>' " .
            "$_SHARED{'geoserver'}/rest/namespaces/$workspace";

    # !!! Если при создании появляется ошибка 500, обычно это проблемы с JOSSO
    $res1 = qx($cmd1);
    if ($res1 eq '500') {
      spi_exec_query("SELECT admin.ov_logoutJOSSO()");
      $res1 = qx($cmd1);
    }
    $res2 = qx($cmd2);

    # Прописываем title и abstract для workspace
#    $rv = spi_exec_query("SELECT title FROM admin.wms_catalog WHERE workspace ilike '$workspace'");
#    my $title = $rv->{rows}[0]->{title};
#    $rv = spi_exec_query("SELECT description FROM admin.wms_catalog WHERE workspace ilike '$workspace'");
#    my $abstract = $rv->{rows}[0]->{description};

    if ($title ne '') {
#      $cmd3 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
#              "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
#              "-XPUT -H 'Content-type: application/xml' " .
#              "-d '<settings><contact><contactPosition>$title</contactPosition></contact></settings>' " .
#              "$_SHARED{'geoserver'}/rest/workspaces/$workspace/settings";
#      $res3 = qx($cmd3);
    }
    if ($abstract ne '') {
#      $cmd3 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
#              "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
#              "-XPUT -H 'Content-type: application/xml' " .
#              "-d '<settings><contact><addressState>$abstract</addressState></contact></settings>' " .
#             "$_SHARED{'geoserver'}/rest/workspaces/$workspace/settings";
#      $res3 = qx($cmd3);
    }

#    spi_exec_query("SELECT admin.ov_reloadGeoserverNodes('$processid')");

    # Итоговая проверка
    $cmd = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
           "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
           "$_SHARED{'geoserver'}/rest/workspaces/$workspace";
    $response = qx($cmd);
  
    if ($response eq '200') {
      spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'createWorkspace', '".time."', '".time."', 'INFO', 'Workspace $workspace created successfully')");
      return "Workspace $workspace created successfully";
    }
    else {
      spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'createWorkspace', '".time."', '".time."', 'ERROR', 'Failed to create workspace $workspace, with codes $res1, $res2, $res3')");
      return "Failed to create workspace $workspace, with codes $res1, $res2, $res3";
    }
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createWorkspace(text, text) IS 'Создание workspace';

--------------------
-- Создание маски --
--------------------
CREATE OR REPLACE FUNCTION admin.ov_createMask(text, text, text) RETURNS text AS $$
  my $processid  = $_[0] ne '' ? $_[0] : time;
  my $resourceid = $_[1];
  my $maskshape  = $_[2];
  my $stageStartTime = time;
  
  # Инициализация глобальных переменных PLPerl
  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Проверяем входные аргументы
  if ($resourceid eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createMask', '$stageStartTime', '".time."', 'ERROR', 'Empty resourceid argument')");
    return 'Empty resourceid argument';
  }
  if ($maskshape eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createMask', '$stageStartTime', '".time."', 'ERROR', 'Empty path to mask file')");
    return 'Empty path to mask file';
  }

  $rv = spi_exec_query("SELECT admin.ov_lcc('$resourceid')");
  my $resource = $rv->{rows}[0]->{ov_lcc};

  # Проверяем существует ли маска?
  $rv = spi_exec_query("SELECT admin.ov_ssh('[ -d $_SHARED{'grasswp'}/ESIMO/$resource/vector/$resource\_mask ] && echo -n t || echo -n f')");
  $maskExists = $rv->{rows}[0]->{ov_ssh};

  if ($maskExists eq 't') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createMask', '$stageStartTime', '".time."', 'INFO', 'Mask $resource\_mask already exists')");
    return "Mask $resource\_mask already exists";
  }
  # Если не существует, то пытаемся создать
  else {
    # Проверяем существует ли указанный шейп для маски?
    $rv = spi_exec_query("SELECT admin.ov_ssh('[ -f $maskshape ] && echo -n t || echo -n f')");
    $shapeExists = $rv->{rows}[0]->{ov_ssh};

    if ($shapeExists eq 't') {
      # Сделать проверку шейпа на валидность !!!

      spi_exec_query("SELECT admin.ov_ssh('$resource', 'v.in.ogr dsn=$maskshape output=$resource\_mask --overwrite')");
      spi_exec_query("SELECT admin.ov_ssh('$resource', 'v.to.rast in=$resource\_mask out=$resource\_mask_rast use=attr col=cat labelcol=cat --overwrite')");
      spi_exec_query("SELECT admin.ov_ssh('$resource', 'r.mask input=$resource\_mask_rast -o --verbose')");

      # Проверяем создалась ли маска?
      $rv = spi_exec_query("SELECT admin.ov_ssh('[ -d $_SHARED{'grasswp'}/ESIMO/$resource/vector/$resource\_mask ] && echo -n t || echo -n f')");
      $maskExists = $rv->{rows}[0]->{ov_ssh};

      if ($maskExists eq 't') {
        spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createMask', '$stageStartTime', '".time."', 'INFO', 'Mask $resource\_mask created successfully')");
        return "Mask $resource\_mask created successfully";
      }
      # И если не создалась, пишел ошибку
      else {
        spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createMask', '$stageStartTime', '".time."', 'ERROR', 'Failed to create mask $resource\_mask')");
        return "Failed to create mask $resource\_mask";
      }
    }
    # Если не существует, пишем ошибку
    else {
      spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createMask', '$stageStartTime', '".time."', 'ERROR', 'Mask ShapeFile $maskshape does not exist')");
      return "Mask ShapeFile '$maskshape' does not exist";
    }
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createMask(text, text, text) IS 'Создание маски';

----------------------------
-- Создание PostGIS Store --
----------------------------
CREATE OR REPLACE FUNCTION admin.ov_createPostgisStore(text, text) RETURNS text AS $$
  my $processid = $_[0] ne '' ? $_[0] : time;
  my $resourceid  = $_[1];
  
  # Инициализация глобальных переменных PLPerl
  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Авторизация в JOSSO
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");

  # Получаем workspace для ресурса
  $rv = spi_exec_query("SELECT admin.ov_getWorkspace('$processid', '$resourceid')");
  my $workspace = $rv->{rows}[0]->{ov_getworkspace};

  # Проверяем существует store
  my $cmd = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " .
            "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
            "$_SHARED{'geoserver'}/rest/workspaces/$workspace/datastores/bid";
  my $response = qx($cmd);

  if ($response eq '200') {
    return "Datastore bid already exists";
  }
  else {
    # Получаем схему БД для ресурса
    $rv = spi_exec_query("SELECT admin.ov_getSchema('$processid', '$resourceid')");
    my $schema = $rv->{rows}[0]->{ov_getschema};

    # Создаем datastore
    $cmd1 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
            "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
            "-XPOST -H 'Content-type: application/xml' " .
            "-d '<dataStore>" .
                "<name>bid</name>" .
                "<type>PostGIS (JNDI)</type>" .
                "<enabled>true</enabled>" .
                "<workspace>" .
                    "<id>$workspace</id>" .
                "</workspace>" .
                "<connectionParameters>" .
		    "<entry key=\"schema\">$schema</entry>" .
                    "<entry key=\"dbtype\">postgis</entry>" .
                    "<entry key=\"Loose bbox\">true</entry>" .
                    "<entry key=\"Expose primary keys\">false</entry>" .
                    "<entry key=\"Max open prepared statements\">50</entry>" .
                    "<entry key=\"preparedStatements\">false</entry>" .
                    "<entry key=\"jndiReferenceName\">java:comp/env/jdbc/bid</entry>" .
                    "<entry key=\"namespace\">$workspace</entry>" .
                "</connectionParameters>" .
            "</dataStore>' " .
            "$_SHARED{'geoserver'}/rest/workspaces/$workspace/datastores";
            
    $res1 = qx($cmd1);

    # Итоговая проверка
    $cmd = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
           "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
           "$_SHARED{'geoserver'}/rest/workspaces/$workspace/datastores/bid";
    $response = qx($cmd);
  
    if ($response eq '200') {
      return "Datastore bid created successfully";
    }
    else {
      return "Failed to create datastore bid, with codes $res1";
    }
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createPostgisStore(text, text) IS 'Создание PostGIS Store';

------------------------------
-- Перезагрузка геосерверов --
------------------------------
CREATE OR REPLACE FUNCTION admin.ov_reloadGeoserverNodes(text) RETURNS text AS $$
  my $processid  = $_[0] ne '' ? $_[0] : time;

  # Инициализация глобальных переменных PLPerl
  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Авторизация в JOSSO
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");

  # Перезагрузка по очереди геосерверов указанных в config_table
  $error = '';
  @nodes = split(/,/, $_SHARED{'gsnodes'});
  foreach $node (@nodes) {
     $cmd = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
            "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
            "-XPOST http://$node/resources/rest/reload";
     $res = qx($cmd);
     $error = 't' if $res ne '200' ;
  }

  # Были ошибки?
  if ($error eq 't') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'reloadGeoserverNodes', '".time."', '".time."', 'ERROR', 'Perhaps there was an error when the geoserver nodes reloads')");
    return 'Perhaps there was an error when the geoserver nodes reloads.'
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'reloadGeoserverNodes', '".time."', '".time."', 'INFO', 'Reload is successful')");
    return 'Reload is successful.';
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_reloadGeoserverNodes(text) IS 'Перезагрузка геосерверов';

-------------------------
-- Логирование событий --
-------------------------
CREATE OR REPLACE FUNCTION admin.ov_logEvent(text, text, text, text, text, text, text, text, text) RETURNS text AS $$
  use POSIX qw(strftime);
  my $componentID       = 'GIS';
  my $nodeID            = $nodeid;
  my $processID         = 'IRBuilder';
  my $processInstanceID = $_[0]; # 123456789
  my $processObjectID   = $_[1]; # RU_Hydrometcentre_42
  my $param             = $_[2] ne '' ? "''$_[2]''" : "NULL";
  my $type              = $_[3] ne '' ? "''$_[3]''" : "NULL";
  my $processSubjectID  = "$nodeID;10.0.5.11";
  my $processStageID    = $_[4];
  my $dateStartPlanned  = '';
  my $dateStartReal     = strftime("%Y-%m-%d %H:%M:%S", localtime($_[5]));
  my $dateFinish        = strftime("%Y-%m-%d %H:%M:%S", localtime($_[6]));
  my $dataVolume        = '0';
  my $logLevel          = $_[7];
  my $errorType         = '';
  my $messageText       = $_[8];

  spi_exec_query("SELECT admin.ov_psql('INSERT INTO admin.process_log (processid, resourceid, param, type, stageid, datestart, datestop, loglevel, message) 
                  VALUES (''$processInstanceID'', ''$processObjectID'', $param, $type, ''$processStageID'', ''$dateStartReal'', ''$dateFinish'', ''$logLevel'', ''$messageText'')')");

  #spi_exec_query("INSERT INTO admin.process_log (processid, resourceid, param, type, stageid, datestart, datestop, loglevel, message) 
  #                VALUES ('$processInstanceID', '$processObjectID', $param, $type, '$processStageID', '$dateStartReal', '$dateFinish', '$logLevel', '$messageText')");

  return 'nothing to return';
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_logEvent(text, text, text, text, text, text, text, text, text) IS 'Логирование событий';













----------------
-- Public API --
----------------
--------------------------------------------------------------------
-- Автоматическая обработка всех ресурсов описанных в admin_table --
--------------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_processAllResources() RETURNS setof text AS $$
DECLARE
  r record;
  result int;
  processid int;
  gis_lc admin.admin_table%rowtype;
  curs refcursor;
  func_call text;
BEGIN
  PERFORM admin.ov_logoutJOSSO();
  SELECT round(extract(epoch FROM now())) INTO processid;

  FOR r IN SELECT * FROM admin.admin_table ORDER BY resourceid LOOP
    --PERFORM admin.ov_psql('SELECT admin.ov_pushInQueue('''|| processid ||''', '''|| r.resourceid ||''', '''|| coalesce(r.param, '') ||''', '''|| r.type ||''')');
    --SELECT admin.ov_psqlb('SELECT admin.ov_processResource('''|| processid ||''', '''|| r.resourceid ||''', '''|| coalesce(r.param, '') ||''', '''|| r.type ||''')') INTO result;
    --SELECT admin.ov_psql('SELECT admin.ov_processResource('''|| processid ||''', '''|| r.resourceid ||''', '''|| coalesce(r.param, '') ||''', '''|| r.type ||''')') INTO result;
    SELECT admin.ov_psql('SELECT admin.ov_processResource('''|| processid ||''', '''|| r.resourceid ||''', '''|| coalesce(r.param, '') ||''', '''|| r.type ||''')') INTO result;
    processid = processid + 1;
    if result = 0 then 
      raise notice '% processed successfully', r.resourceid;
    else
      raise notice '% processed with errors', r.resourceid;
    end if;
    RETURN NEXT result;
  END LOOP;
END
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION admin.ov_processAllResources() IS 'Автоматическая обработка всех ресурсов описанных в admin_table';

---------------------------------------------------------------
-- Автоматическая обработка ресурса описанного в admin_table --
---------------------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_processResource(text, text, text, text) RETURNS integer AS $$
  my $processid  = $_[0] ne '' ? $_[0] : time;
  my $resourceid = $_[1];
  my $param      = $_[2];
  my $type       = $_[3];
  my $stageStartTime = time;
  my ($action, $result1, $result2, $result3, $err1, $err2);

  spi_exec_query('SELECT admin.ov_initPLPerl()');

  # Проверям входные аргументы
  if ($resourceid eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '$stageStartTime', '".time."', 'ERROR', 'Empty resourceid argument')");
    return 1;
  }
  if ($type eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '$stageStartTime', '".time."', 'ERROR', 'Empty type argument')");
    return 1;
  }
  elsif ($type ne 'pt' and $param eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '$stageStartTime', '".time."', 'ERROR', 'Empty param argument for $type')");
    return 1;
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '$stageStartTime', '".time."', 'INFO', 'Input arguments $processid, $resourceid, $param, $type')");
  }

  # Проверяeм описан ли ресурс в admin_table
  $rv = spi_exec_query("SELECT resourceid FROM admin.admin_table WHERE resourceid ILIKE '$resourceid' LIMIT 1");
  $resourceidAttend = $rv->{rows}[0]->{resourceid};
  if ($resourceidAttend eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '".time."', '".time."', 'ERROR', 'Resourceid $resourceid is not present in admin_table')");
    return 1;
  }  

  # Проверяем есть ли колонка action
  $rv = spi_exec_query("SELECT column_name FROM information_schema.columns WHERE table_schema='admin' and table_name='admin_table' and column_name='action'");
  $actionExist = $rv->{rows}[0]->{column_name};
  if ($actionExist eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '".time."', '".time."', 'ERROR', 'Resourceid $resourceid is not present in admin_table')");
    return 1;
  }  
  
  if ($type eq 'pt') {
    $rv = spi_exec_query("SELECT action FROM admin.admin_table WHERE resourceid ilike '$resourceid' AND type = '$type'");
    $action = $rv->{rows}[0]->{action};
  }
  elsif ($type =~ /ln|sf|tr|pl/) {
    $rv = spi_exec_query("SELECT action FROM admin.admin_table WHERE resourceid ilike '$resourceid' AND param = '$param' AND type = '$type'");
    $action = $rv->{rows}[0]->{action};
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '".time."', '".time."', 'ERROR', 'Wrong type argument')");
    return 1;
  }
  if ($action eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '".time."', '".time."', 'ERROR', 'Empty action for resourceid $resourceid')");
    return 1;
  }

  if ($action =~ /builddata/) {
     $rv = spi_exec_query("SELECT admin.ov_psql('SELECT admin.ov_createResource(''$processid'', ''$resourceid'', ''$param'', ''$type'')')");
     $result1 = $rv->{rows}[0]->{ov_psql};
    $result1 = ' ';
  }
  else {
     $result1 = 'No indication to build data';
  }
  if ($action =~ /publishlayer/) {
     $rv = spi_exec_query("SELECT admin.ov_psql('SELECT admin.ov_publishResource(''$processid'', ''$resourceid'', ''$param'', ''$type'')')");
     $result2 = $rv->{rows}[0]->{ov_psql};
  }
  else {
     $result2 = 'No indication to publish layer';
  }
  
  if ($result1 eq '') {
    $result1 = "Empty result, see previous messages";
    $err1 = '1';
  }
  if ($result2 eq '') {
    $result2 = "Empty result, see previous messages";
    $err1 = '1';
  }

  $rv = spi_exec_query("SELECT loglevel FROM admin.process_log WHERE processid = '$processid' AND loglevel = 'ERROR'");
  $err2 = $rv->{rows}[0]->{loglevel};

  if ($err1 ne '' or $err2 ne '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '$stageStartTime', '".time."', 'ERROR', '$result1. $result2.')");
    return 1;
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'processResource', '$stageStartTime', '".time."', 'INFO', '$result1. $result2.')");
    return 0;
  }  
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_processResource(text, text, text, text) IS 'Автоматическая обработка ресурса описанного в admin_table';

-------------------------------------------------
-- Построение ресурса описанного в admin_table --
-------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_createResource(text, text, text, text) RETURNS text AS $$
  my $processid   = $_[0] ne '' ? $_[0] : time;
  my $resourceid  = $_[1];
  my $param       = $_[2];
  my $type        = $_[3];

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Построение точек
  if ($type eq 'pt') {
    $rv = spi_exec_query("SELECT admin.ov_createPoints('$processid', '$resourceid')");
    $result = $rv->{rows}[0]->{ov_createpoints};
    return $result;
  }
  
  # Построение поверхности
  elsif ($type eq 'sf') {
    $rv = spi_exec_query("SELECT cellsize FROM admin.admin_table WHERE resourceid = '$resourceid' AND param = '$param' AND type = '$type' LIMIT 1");
    $cellsize = $rv->{rows}[0]->{cellsize};
    $rv = spi_exec_query("SELECT mask FROM admin.admin_table WHERE resourceid = '$resourceid' AND param = '$param' AND type = '$type' LIMIT 1");
    $mask = $rv->{rows}[0]->{mask};

    $rv = spi_exec_query("SELECT admin.ov_createSurface('$processid', '$resourceid', '$param', '$cellsize', '$mask')");
    $result = $rv->{rows}[0]->{ov_createsurface};
    return $result;
  }

  # Построение изолиний
  elsif ($type eq 'ln') {
    $rv = spi_exec_query("SELECT cellsize FROM admin.admin_table WHERE resourceid = '$resourceid' AND param = '$param' AND type = '$type' LIMIT 1");
    $cellsize = $rv->{rows}[0]->{cellsize};
    $rv = spi_exec_query("SELECT step FROM admin.admin_table WHERE resourceid = '$resourceid' AND param = '$param' AND type = '$type' LIMIT 1");
    $step = $rv->{rows}[0]->{step};
    $rv = spi_exec_query("SELECT minlevel FROM admin.admin_table WHERE resourceid = '$resourceid' AND param = '$param' AND type = '$type' LIMIT 1");
    $minlevel = $rv->{rows}[0]->{minlevel};
    $rv = spi_exec_query("SELECT maxlevel FROM admin.admin_table WHERE resourceid = '$resourceid' AND param = '$param' AND type = '$type' LIMIT 1");
    $maxlevel = $rv->{rows}[0]->{maxlevel};
    $rv = spi_exec_query("SELECT mask FROM admin.admin_table WHERE resourceid = '$resourceid' AND param = '$param' AND type = '$type' LIMIT 1");
    $mask = $rv->{rows}[0]->{mask};
    
    $rv = spi_exec_query("SELECT admin.ov_createIsolines('$processid', '$resourceid', '$param', '$cellsize', '$step', '$minlevel', '$maxlevel', '$mask')");
    $result = $rv->{rows}[0]->{ov_createisolines};
    return $result;
  }

  # Построение трэков
  elsif ($type eq 'tr') {
    $rv = spi_exec_query("SELECT admin.ov_createTracks('$resourceid')");
    $result = $rv->{rows}[0]->{ov_createtracks};
    return $result;
  }

  # Построение полигонов
  elsif ($type eq 'pl') {
    $rv = spi_exec_query("SELECT admin.ov_createPolygons('$resourceid', '$param')");
    $result = $rv->{rows}[0]->{ov_createpolygons};
    return $result;
  }

  # Во всех остальных случаях
  else {
    return 'Wrong input type argument';
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createResource(text, text, text, text) IS 'Построение ресурса описанного в admin_table';

----------------------
-- Построение точек --
----------------------
CREATE OR REPLACE FUNCTION admin.ov_createPoints(text, text) RETURNS text AS $$
  my $processid  = $_[0] ne '' ? $_[0] : time;
  my $resourceid = $_[1];
  my $stageStartTime = time;

  #spi_exec_query("SELECT admin.ov_pushInQueue('$processid', '$resourceid', '', 'pt')");

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Получаем схему БД для ресурса
  $rv = spi_exec_query("SELECT admin.ov_getSchema('$processid', '$resourceid')");
  my $schema = $rv->{rows}[0]->{ov_getschema};

  # Создание колонки геометрии и первичного ключа для таблицы точек
  # Использование psql необходимо из-за невозможности выполнить транзакцию в процедуре PlPgSQL
  $rv = spi_exec_query("SELECT admin.ov_psql('SELECT admin.ov_addGeometryColumn(''$processid'', ''$resourceid'')')");
  $result1 = $rv->{rows}[0]->{ov_psql};
  $rv = spi_exec_query("SELECT admin.ov_psql('SELECT admin.ov_addPrimaryKey(''$processid'', ''$resourceid'')')");
  $result2 = $rv->{rows}[0]->{ov_psql};
  if ($schema ne '') {
    $rv = spi_exec_query("SELECT admin.ov_psql('SELECT Populate_Geometry_Columns(''$schema.$resourceid''::regclass)')");
    $result3 = $rv->{rows}[0]->{ov_psql};
  }
  
  #spi_exec_query("SELECT admin.ov_popFromQueue('$processid', '$resourceid', '', 'pt')");

  #spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'createPoints', '$stageStartTime', '".time."', 'INFO', '$result1. $result2.')");
  return "$result1. $result2.";
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createPoints(text, text) IS 'Построение точек';

----------------------------
-- Построение поверхности --
----------------------------
CREATE OR REPLACE FUNCTION admin.ov_createSurface(text, text, text, text, text) RETURNS text AS $$
  my $processid   = $_[0] ne '' ? $_[0] : time;
  my $resourceid  = $_[1];
  my $param       = $_[2];
  my $cellsize    = $_[3];
  my $mask        = $_[4];

  #spi_exec_query("SELECT admin.ov_pushInQueue('$processid', '$resourceid', '$param', 'sf')");

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  $rv = spi_exec_query("SELECT admin.ov_psql('SELECT admin.ov_createPoints(''$processid'', ''$resourceid'')')");
  $result = $rv->{rows}[0]->{ov_psql};

  my $stageStartTime = time;

  # Получаем схему БД для ресурса
  $rv = spi_exec_query("SELECT admin.ov_getSchema('$processid', '$resourceid')");
  $schema = $rv->{rows}[0]->{ov_getschema};

  $rv = spi_exec_query("SELECT admin.ov_lcc('$resourceid')");
  my $resource = $rv->{rows}[0]->{ov_lcc};

  # Создаем маску
  $rv = spi_exec_query("SELECT admin.ov_createMask('$processid', '$resourceid', '$mask')");
  my $maskResult = $rv->{rows}[0]->{ov_createmask};
  
  # Импорт точек из БД в GRASS
  # Внимание! Так как импортированные точки не удаляются после обработки ресурса
  # требуется достаточно свободного места на узле
  #spi_exec_query("SELECT admin.ov_ssh('$resource', 'v.external dsn=\"PG:host=$_SHARED{'dbhost'} port=$_SHARED{'dbport'} dbname=$_SHARED{'dbname'} user=$_SHARED{'dbuser'} password=$_SHARED{'dbpass'}\" layer=$schema.$resource output=$resource --overwrite')");

  ### Здесь начинается магия ###
  # Проверяем импортированны точки в GRASS или нет?
  $rv = spi_exec_query("SELECT admin.ov_ssh('[ -f $_SHARED{'grasswp'}/ESIMO/$resource/dbf/$resource.dbf ] && echo -n t || echo -n f')");
  $pointsImported = $rv->{rows}[0]->{ov_ssh};

  # Есть ли в ИР колонка с датой?
  $rv = spi_exec_query("SELECT column_name FROM information_schema.columns WHERE table_name='$resource' AND table_schema='$schema' AND column_name='m4400'");
  $m4400IsPresent = $rv->{rows}[0]->{column_name};

  if ($m4400IsPresent ne '') {
    # Если точки уже импортированны, сверяем дату с БД
    if ($pointsImported eq 't') {
      $rv = spi_exec_query("SELECT m4400 FROM $resource LIMIT 1");
      $dateFromBID = $rv->{rows}[0]->{m4400};
      $rv = spi_exec_query("SELECT admin.ov_ssh('cat $_SHARED{'grasswp'}/ESIMO/$resource/datetime')");
      $dateFromFile = $rv->{rows}[0]->{ov_ssh};
      if ($dateFromBID eq $dateFromFile) {
        $pointsActual = 't';
      }
      else {
        $pointsActual = 'f';
      }
    }
    if ($pointsImported eq 'f' or $pointsActual eq 'f') {
      spi_exec_query("SELECT admin.ov_ssh('$resource', 'db.connect driver=dbf database=\"$_SHARED{'grasswp'}/ESIMO/$resource/dbf/\" schema=\"\"')");
      spi_exec_query("SELECT admin.ov_ssh('$resource', 'v.in.ogr dsn=\"PG:host=$_SHARED{'dbhost'} port=$_SHARED{'dbport'} dbname=$_SHARED{'dbname'} user=$_SHARED{'dbuser'} password=$_SHARED{'dbpass'}\" layer=$schema.$resource output=$resource type=point -o --overwrite')");
      $rv = spi_exec_query("SELECT m4400 FROM $resource LIMIT 1");
      $m4400 = $rv->{rows}[0]->{m4400};
      spi_exec_query("SELECT admin.ov_ssh('echo -n $m4400 > $_SHARED{'grasswp'}/ESIMO/$resource/datetime')");
    }
  }
  else {
      spi_exec_query("SELECT admin.ov_ssh('$resource', 'db.connect driver=dbf database=\"$_SHARED{'grasswp'}/ESIMO/$resource/dbf/\" schema=\"\"')");
      spi_exec_query("SELECT admin.ov_ssh('$resource', 'v.in.ogr dsn=\"PG:host=$_SHARED{'dbhost'} port=$_SHARED{'dbport'} dbname=$_SHARED{'dbname'} user=$_SHARED{'dbuser'} password=$_SHARED{'dbpass'}\" layer=$schema.$resource output=$resource type=point -o --overwrite')");
  }
  ### Магия закончилась ###
  
  # Установка размера ячейки
  $cellsize = 0.2 if $cellsize eq '';
  spi_exec_query("SELECT admin.ov_ssh('$resource', 'g.region -p vect=$resource res=$cellsize')");

  # Построение поверхности используя алгоритм IDW  
  spi_exec_query("SELECT admin.ov_ssh('$resource', 'v.surf.idw input=$resource output=$resource\_$param\_sf npoints=12 power=2.0 layer=1 column=$param --overwrite')");

  # Экспорт поверхности в TIFF
  spi_exec_query("SELECT admin.ov_ssh('$resource', 'r.colors map=$resource\_$param\_sf color=grey')");
  spi_exec_query("SELECT admin.ov_ssh('$resource', 'r.out.gdal input=$resource\_$param\_sf output=$_SHARED{'imgpath'}/$resource\_$param\_sf.tif format=GTiff type=Int32 createopt=\"TFW=YES\"')");

  #spi_exec_query("SELECT admin.ov_popFromQueue('$processid', '$resourceid', '$param', 'sf')");

  # Итоговая проверка
  $rv = spi_exec_query("SELECT admin.ov_ssh('[ -f $_SHARED{'imgpath'}/$resource\_$param\_sf.tif ] && echo -n t || echo -n f')");
  $exist = $rv->{rows}[0]->{ov_ssh};
  if ($exist eq 't') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createSurface', '$stageStartTime', '".time."', 'INFO', 'Surface $resource\_$param\_sf created successfully')");
    return "Surface $resource\_$param\_sf created successfully";
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createSurface', '$stageStartTime', '".time."', 'ERROR', 'Error while creating the surface $resource\_$param\_sf')");
    return "Error while creating the surface $resource\_$param\_sf";
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createSurface(text, text, text, text, text) IS 'Построение поверхности';

-------------------------
-- Построение изолиний --
-------------------------
CREATE OR REPLACE FUNCTION admin.ov_createIsolines(text, text, text, text, text, text, text, text) RETURNS text AS $$
  my $processid   = $_[0] ne '' ? $_[0] : time;
  my $resourceid  = $_[1];
  my $param       = $_[2];
  my $cellsize    = $_[3];
  my $step        = $_[4];
  my $minlevel    = $_[5];
  my $maxlevel    = $_[6];
  my $mask        = $_[7];

  #spi_exec_query("SELECT admin.ov_pushInQueue('$processid', '$resourceid', '$param', 'ln')");

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  $rv = spi_exec_query("SELECT admin.ov_psql('SELECT admin.ov_createSurface(''$processid'', ''$resourceid'', ''$param'', ''$cellsize'', ''$mask'')')");
  $result = $rv->{rows}[0]->{ov_psql};

  my $stageStartTime = time;

  # Получаем схему БД для ресурса
  $rv = spi_exec_query("SELECT admin.ov_getSchema('$processid', '$resourceid')");
  $schema = $rv->{rows}[0]->{ov_getschema};

  $rv = spi_exec_query("SELECT admin.ov_lcc('$resourceid')");
  my $resource = $rv->{rows}[0]->{ov_lcc};  

  if ($step eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createIsolines', '".time."', '".time."', 'ERROR', 'Empty step for $resource\_$param\_ln in admin_table')");
    return "Empty step for $resource\_$param\_ln in admin_table";
  }
  if ($minlevel eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createIsolines', '".time."', '".time."', 'ERROR', 'Empty minlevel for $resource\_$param\_ln in admin_table')");
    return "Empty minlevel for $resource\_$param\_ln in admin_table";
  }
  if ($maxlevel eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createIsolines', '".time."', '".time."', 'ERROR', 'Empty maxlevel for $resource\_$param\_ln in admin_table')");
    return "Empty maxlevel for $resource\_$param\_ln in admin_table";
  }

  spi_exec_query("SELECT admin.ov_ssh('$resource', 'r.in.gdal input=$_SHARED{'imgpath'}/$resource\_$param\_sf.tif output=$resource\_$param\_sf --overwrite')");
  spi_exec_query("SELECT admin.ov_ssh('$resource', 'r.contour input=$resource\_$param\_sf output=$resource\_$param\_ln step=$step minlevel=$minlevel maxlevel=$maxlevel --overwrite')");
  spi_exec_query("SELECT admin.ov_ssh('$resource', 'v.generalize input=$resource\_$param\_ln output=$resource\_$param\_ln_smooth method=boyle threshold=1.0 look_ahead=4 -c --overwrite')");
  spi_exec_query("SELECT admin.ov_ssh('$resource', 'v.out.ogr -s input=$resource\_$param\_ln_smooth olayer=$schema.$resource\_$param\_ln dsn=\"PG:host=$_SHARED{'dbhost'} port=$_SHARED{'dbport'} dbname=$_SHARED{'dbname'} user=$_SHARED{'dbuser'} password=$_SHARED{'dbpass'}\" type=line format=PostgreSQL lco=\"OVERWRITE=YES,GEOMETRY_NAME=the_geom,FID=id\" --overwrite')");

  #spi_exec_query("SELECT admin.ov_popFromQueue('$processid', '$resourceid', '$param', 'ln')");

  $rv = spi_exec_query("SELECT admin.ov_isTableExists('$resource\_$param\_ln', '$schema')");
  $exist = $rv->{rows}[0]->{ov_istableexists};
  if ($exist eq 't') {
    #spi_exec_query("DELETE FROM $schema.$resource\_$param\_ln WHERE ST_Length(the_geom) < 10.0");
    # Есть ли колонка level?
    $rv = spi_exec_query("SELECT column_name FROM information_schema.columns WHERE table_name='$resource\_$param\_ln' AND table_schema='$schema' AND column_name='level'");
    $levelIsPresent = $rv->{rows}[0]->{column_name};
    if ($levelIsPresent ne '') {
      spi_exec_query("ALTER TABLE $schema.$resource\_$param\_ln RENAME COLUMN \"level\" TO $param");
    }
    else {
      # Если изолиний нет, создаем колонку для совместимости с geoserver
      spi_exec_query("ALTER TABLE $schema.$resource\_$param\_ln ADD COLUMN $param real");
      #spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createIsolines', '$stageStartTime', '".time."', 'ERROR', 'There is no level column in $resource\_$param\_ln table')");
      #return "ERROR There is no level column in $resource\_$param\_ln table";
    }
    spi_exec_query("ALTER TABLE $schema.$resource\_$param\_ln ADD COLUMN m4400 character varying(20)");
    spi_exec_query("UPDATE $schema.$resource\_$param\_ln SET m4400 = (select m4400 from $schema.$resource limit 1)");

    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createIsolines', '$stageStartTime', '".time."', 'INFO', 'Isolines $resource\_$param\_ln created successfully')");
    return "Isolines $resource\_$param\_ln created successfully";
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', '$param', '$type', 'createIsolines', '$stageStartTime', '".time."', 'ERROR', 'Error while creating an isolines $resource\_$param\_ln')");
    return "Error while creating an isolines $resource\_$param\_ln";
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createIsolines(text, text, text, text, text, text, text, text) IS 'Построение изолиний';

-----------------------
-- Построение трэков --
-----------------------
CREATE OR REPLACE FUNCTION admin.ov_createTracks(text) RETURNS text AS $$
  $resourceid  = $_[0];

  return 'Nothing to do';
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createTracks(text) IS 'Построение трэков';

--------------------------
-- Построение полигонов --
--------------------------
CREATE OR REPLACE FUNCTION admin.ov_createPolygons(text, text) RETURNS text AS $$
  $resourceid  = $_[0];
  $param       = $_[1];

  return 'Nothing to do';
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_createPolygons(text, text) IS 'Построение полигонов';

-------------------------------------------------
-- Публикация ресурса описанного в admin_table --
-------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_publishResource(text, text, text, text) RETURNS text AS $$
  my $processid   = $_[0] ne '' ? $_[0] : time;
  my $resourceid  = $_[1];
  my $param       = $_[2];
  my $type        = $_[3];

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");

  # Инициализация переменных
  $rv = spi_exec_query("SELECT admin.ov_getWorkspace('$processid', '$resourceid')");
  $workspace = $rv->{rows}[0]->{ov_getworkspace};
  $rv = spi_exec_query("SELECT admin.ov_getLayername('$resourceid', '$param', '$type')");
  $layername = $rv->{rows}[0]->{ov_getlayername};
  $rv = spi_exec_query("SELECT admin.ov_getLayerTitle('$resourceid', '$param', '$type')");
  $title = $rv->{rows}[0]->{ov_getlayertitle};
  $rv = spi_exec_query("SELECT admin.ov_getResourceDescription('$resourceid')");
  $description = $rv->{rows}[0]->{ov_getresourcedescription};
  $rv = spi_exec_query("SELECT admin.ov_getLayerKeywords('$resourceid')");
  $keywords = $rv->{rows}[0]->{ov_getlayerkeywords};
  $rv = spi_exec_query("SELECT admin.ov_getLayerDefaultStyle('$resourceid', '$param', '$type')");
  $defaultstyle = $rv->{rows}[0]->{ov_getlayerdefaultstyle};
  $rv = spi_exec_query("SELECT admin.ov_getLayerStyles('$resourceid', '$param', '$type')");
  $styles = $rv->{rows}[0]->{ov_getlayerstyles};
  $rv = spi_exec_query("SELECT admin.ov_getSchema('$processid', '$resourceid')");
  $schema = $rv->{rows}[0]->{ov_getschema};
  $rv = spi_exec_query("SELECT admin.ov_lcc('$resourceid')");
  $tablename = $rv->{rows}[0]->{ov_lcc};

  if ($type eq 'pt') {
    $rv = spi_exec_query("SELECT defaultstyle FROM admin.admin_table WHERE resourceid = '$resourceid' AND type = '$type'");
    $dstyle = $rv->{rows}[0]->{defaultstyle};
  }
  else {
    $rv = spi_exec_query("SELECT defaultstyle FROM admin.admin_table WHERE resourceid = '$resourceid' AND param = '$param' AND type = '$type'");
    $dstyle = $rv->{rows}[0]->{defaultstyle};
  }

  # Публикация точек
  if ($type eq 'pt') {
    $rv = spi_exec_query("SELECT admin.ov_publishPostgis('$processid', '$resourceid', '$workspace', '$layername', '$title', '$description', '$keywords', '$defaultstyle', '$styles', '$schema', '$tablename')");
    $result = $rv->{rows}[0]->{ov_publishpostgis};
    return $result;
  }
  # Публикация изолиний/трэков/полигонов
  elsif (($type eq 'ln') or ($type eq 'tr') or ($type eq 'pl')) {
    $rv = spi_exec_query("SELECT admin.ov_publishPostgis('$processid', '$resourceid', '$workspace', '$layername', '$title', '$description', '$param', '$defaultstyle', '$styles', '$schema', '$tablename')");
    $result = $rv->{rows}[0]->{ov_publishpostgis};
    return $result;
  }
  # Публикация поверхности
  elsif ($type eq 'sf') {
    $rv = spi_exec_query("SELECT admin.ov_publishGeoTIFF('$processid', '$resourceid', '$workspace', '$layername', '$title', '$description', '$param', '$defaultstyle', '$styles', '$_SHARED{'imgpath'}/$layername.tif')");
    $result = $rv->{rows}[0]->{ov_publishgeotiff};
    return $result;
  }
  # Во всех остальных случаях
  else {
    return 'Wrong input argument $type';
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_publishResource(text, text, text, text) IS 'Публикация ресурса описанного в admin_table';

-------------------------------------------------
-- Публикация пространственной таблицы Postgis --
-------------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_publishPostgis(text, text, text, text, text, text, text, text, text, text, text) RETURNS text AS $$
  my $processid    = $_[0] ne '' ? $_[0] : time;
  my $resourceid   = $_[1];
  my $workspace    = $_[2];
  my $layername    = $_[3];
  my $title        = $_[4];
  my $description  = $_[5];
  my $keywords     = $_[6];
  my $defaultstyle = $_[7];
  my $styles       = $_[8];
  my $schema       = $_[9];
  my $tablename    = $_[10];
  my $stageStartTime = time;

  # Обязательные поля
  if ($resourceid eq '' or $workspace eq '' or $layername eq '' or $title eq '' or $defaultstyle eq '' or $schema eq '' or $tablename eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishPostgis', '$stageStartTime', '".time."', 'ERROR', 'Fill all required arguments')");
    return "Fill all required arguments '$resourceid', '$workspace', '$layername', '$title', '$defaultstyle', '$schema', '$tablename'";
  }

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");

  $rv = spi_exec_query("SELECT admin.ov_getLayerBBoxXML('$processid', '$resourceid')");
  $bboxxml = $rv->{rows}[0]->{ov_getlayerbboxxml};

  # Обработка ключевых слов
  if ($keywords ne '') {
    $xml = '';
    @list = split(/,/, $keywords);
    foreach $keyword (@list) {$xml .= "<string>$keyword</string>";}
    $keywordsxml = "<keywords>$xml</keywords>";
  }

  # Обработка стилей
  if ($styles ne '') {
    $xml = '';
    $styles =~ s/\s+//g;
    @list = split(/,/, $styles);
    foreach $style (@list) {$xml .= "<style>$style</style>";}
    $stylesxml = "<styles>$xml</styles>";
  }  

  $rv = spi_exec_query("SELECT admin.ov_createWorkspace('$processid', '$workspace')");
  $createWorkspaceLog = $rv->{rows}[0]->{ov_createworkspace};
  $rv = spi_exec_query("SELECT admin.ov_createPostgisStore('$processid', '$resourceid')");
  $createPostgisStoreLog = $rv->{rows}[0]->{ov_createpostgisstore};

  $response = `curl --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/layers/$workspace\:$layername`;
  if ($response eq '200') {
    spi_exec_query("SELECT admin.ov_removeLayer('$processid', '$workspace', '$layername')");
  }
  
  $cmd1 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
          "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
          "-XPOST -H 'Content-type: application/xml' " .
          "-d '<featureType>" .
              "<name>$layername</name>" .
              "<nativeName>$layername</nativeName>" .
              "<title>$title</title>" .
              "<abstract>$description</abstract>" .
                  $keywordsxml .
              "<nativeCRS>" .
                  "GEOGCS[&quot;WGS 84&quot;,DATUM[&quot;World Geodetic System 1984&quot;," .
                  "SPHEROID[&quot;WGS 84&quot;,6378137.0, 298.257223563, AUTHORITY[&quot;EPSG&quot;," .
                  "&quot;7030&quot;]],AUTHORITY[&quot;EPSG&quot;,&quot;6326&quot;]],PRIMEM[&quot;" .
                  "Greenwich&quot;, 0.0, AUTHORITY[&quot;EPSG&quot;,&quot;8901&quot;]],UNIT[&quot;" .
                  "degree&quot;, 0.017453292519943295],AXIS[&quot;Geodetic longitude&quot;, EAST]," .
                  "AXIS[&quot;Geodetic latitude&quot;, NORTH],AUTHORITY[&quot;EPSG&quot;,&quot;4326&quot;]]" .
              "</nativeCRS>" .
              "<srs>EPSG:4326</srs>" .
              "<nativeBoundingBox>" .
                  $bboxxml .
              "</nativeBoundingBox>" .
              "<latLonBoundingBox>" .
                  $bboxxml .
              "</latLonBoundingBox>" .
              "<enabled>true</enabled>" .
              "</featureType>' " .
	  "$_SHARED{'geoserver'}/rest/workspaces/$workspace/datastores/bid/featuretypes";
  $cmd2 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
          "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
          "-XPUT -H 'Content-type: application/xml' " .
          "-d '<layer>" .
              "<defaultStyle>" .
                  "<name>$dstyle</name>" .
              "</defaultStyle>" .
                  $stylesxml .
              "<enabled>true</enabled>" .
              "</layer>' " .
          "$_SHARED{'geoserver'}/rest/layers/$workspace\:$layername";
  $res1 = qx($cmd1);
  $res2 = qx($cmd2);

#  spi_exec_query("SELECT admin.ov_reloadGeoserverNodes('$processid')");

  $rv = spi_exec_query("SELECT admin.ov_isLayerExists('$processid', '$workspace', '$layername')");
  $exists = $rv->{rows}[0]->{ov_islayerexists};

  $type = substr($layername, -2);

  if ($exists eq 't') {
    spi_exec_query("UPDATE admin.admin_table SET publishedonce = true WHERE resourceid = '$resourceid' AND type = '$type'");
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishPostgis', '$stageStartTime', '".time."', 'INFO', 'Layer $layername published successfully')");
    return "$createWorkspaceLog. $createPostgisStoreLog. Layer $layername published successfully";
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishPostgis', '$stageStartTime', '".time."', 'ERROR', 'Failed to publish layer $layername, with codes $res1, $res2')");
    return "$createWorkspaceLog. $createPostgisStoreLog. Failed to publish layer $layername, with codes $res1, $res2";
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_publishPostgis(text, text, text, text, text, text, text, text, text, text, text) IS 'Публикация пространственной таблицы Postgis';

------------------------
-- Публикация GeoTIFF --
------------------------
CREATE OR REPLACE FUNCTION admin.ov_publishGeoTIFF(text, text, text, text, text, text, text, text, text, text) RETURNS text AS $$
  my $processid    = $_[0] ne '' ? $_[0] : time;
  my $resourceid   = $_[1];
  my $workspace    = $_[2];
  my $layername    = $_[3];
  my $title        = $_[4];
  my $description  = $_[5];
  my $keywords     = $_[6];
  my $defaultstyle = $_[7];
  my $styles       = $_[8];
  my $pathtofile   = $_[9];
  my $stageStartTime = time;

  # Обязательные поля
  if ($resourceid eq '' or $workspace eq '' or $layername eq '' or $title eq '' or $defaultstyle eq '' or $pathtofile eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishGeoTIFF', '$stageStartTime', '".time."', 'ERROR', 'Fill all required arguments')");
    return "Fill all required arguments";
  }

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");

  $rv = spi_exec_query("SELECT admin.ov_getLayerBBoxXML('$processid', '$resourceid')");
  $bboxxml = $rv->{rows}[0]->{ov_getlayerbboxxml};
  $rv = spi_exec_query("SELECT admin.ov_getLayerGridXML('$pathtofile')");
  $gridxml = $rv->{rows}[0]->{ov_getlayergridxml};

  # Обработка ключевых слов
  if ($keywords ne '') {
    $xml = '';
    @list = split(/,/, $keywords);
    foreach $keyword (@list) {$xml .= "<string>$keyword</string>";}
    $keywordsxml = "<keywords>$xml</keywords>";
  }

  # Обработка стилей
  if ($styles ne '') {
    $xml = '';
    $styles =~ s/\s+//g;
    @list = split(/,/, $styles);
    foreach $style (@list) {$xml .= "<style>$style</style>";}
    $stylesxml = "<styles>$xml</styles>";
  }  

  $rv = spi_exec_query("SELECT admin.ov_createWorkspace('$processid', '$workspace')");
  $createWorkspaceLog = $rv->{rows}[0]->{ov_createworkspace};

  my $response = `curl --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/layers/$workspace\:$layername`;
  if ($response eq '200') {
    spi_exec_query("SELECT admin.ov_removeLayer('$processid', '$workspace', '$layername')");
  }

  $cmd0 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
          "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
          "-XPOST -H 'Content-type: application/xml' " .
          "-d '<coverageStore>" .
                "<name>$layername</name>" .
                "<type>GeoTIFF</type>" .
                "<workspace>" .
                    "<id>$workspace</id>" .
                "</workspace>" .
                "<enabled>true</enabled>" .
                "<url>file://$_SHARED{'imgpath'}/$layername.tif</url>" .
              "</coverageStore>' " .
          "$_SHARED{'geoserver'}/rest/workspaces/$workspace/coveragestores";
  $cmd1 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
          "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
          "-XPOST -H 'Content-type: application/xml' " .
          "-d '<coverage>" .
                "<name>$layername</name>" .
                "<nativeName>$layername</nativeName>" .
                "<title>$title</title>" .
                "<abstract>$description</abstract>" .
                    $keywordsxml .
                "<nativeCRS>" .
                    "GEOGCS[&quot;WGS 84&quot;,DATUM[&quot;World Geodetic System 1984&quot;," .
                    "SPHEROID[&quot;WGS 84&quot;,6378137.0, 298.257223563, AUTHORITY[&quot;EPSG&quot;," .
                    "&quot;7030&quot;]],AUTHORITY[&quot;EPSG&quot;,&quot;6326&quot;]],PRIMEM[&quot;" .
                    "Greenwich&quot;, 0.0, AUTHORITY[&quot;EPSG&quot;,&quot;8901&quot;]],UNIT[&quot;" .
                    "degree&quot;, 0.017453292519943295],AXIS[&quot;Geodetic longitude&quot;, EAST]," .
                    "AXIS[&quot;Geodetic latitude&quot;, NORTH],AUTHORITY[&quot;EPSG&quot;,&quot;4326&quot;]]" .
                "</nativeCRS>" .
                "<srs>EPSG:4326</srs>" .
                "<nativeBoundingBox>" .
                    $bboxxml .
                "</nativeBoundingBox>" .
                "<latLonBoundingBox>" .
                    $bboxxml .
                "</latLonBoundingBox>" .
                "<enabled>true</enabled>" .
                "<grid dimension=\"2\">" .
                    $gridxml .
                "</grid>" .
                "<nativeFormat>GeoTIFF</nativeFormat>" .
                "<supportedFormats>" .
                    "<string>GIF</string>" .
                    "<string>PNG</string>" .
                    "<string>JPEG</string>" .
                    "<string>TIFF</string>" .
                    "<string>GEOTIFF</string>" .
                    "<string>GTOPO30</string>" .
                    "<string>IMAGEMOSAIC</string>" .
                    "<string>ARCGRID</string>" .
                "</supportedFormats>" .
                "<projectionPolicy>REPROJECT_TO_DECLARED</projectionPolicy>" .
                "<defaultInterpolationMethod>bilinear</defaultInterpolationMethod>" .
                "<interpolationMethods>" .
                    "<string>nearest neighbour</string>" .
                    "<string>bilinear</string>" .
                    "<string>bicubic</string>" .
                "</interpolationMethods>" .
            "</coverage>' " .
          "$_SHARED{'geoserver'}/rest/workspaces/$workspace/coveragestores/$layername/coverages";
  $cmd2 = "curl --location-trusted -s -o /dev/null -w \"%{http_code}\" " . 
          "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
          "-XPUT -H 'Content-type: application/xml' " .
          "-d '<layer>" .
              "<defaultStyle>" .
                  "<name>$dstyle</name>" .
              "</defaultStyle>" .
                  $stylesxml .
              "<enabled>true</enabled>" .
              "</layer>' " .
          "$_SHARED{'geoserver'}/rest/layers/$workspace\:$layername";
  $res0 = qx($cmd0);
  $res1 = qx($cmd1);
  $res2 = qx($cmd2);

#  spi_exec_query("SELECT admin.ov_reloadGeoserverNodes('$processid')");

  $rv = spi_exec_query("SELECT admin.ov_isLayerExists('$processid', '$workspace', '$layername')");
  $exists = $rv->{rows}[0]->{ov_islayerexists};

  if ($exists eq 't') {
    spi_exec_query("UPDATE admin.admin_table SET publishedonce = true WHERE resourceid = '$resourceid' AND type = 'sf'");
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishGeoTIFF', '$stageStartTime', '".time."', 'INFO', 'Layer $layername published successfully')");
    return "$createWorkspaceLog. Layer $layername published successfully";
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishGeoTIFF', '$stageStartTime', '".time."', 'ERROR', 'Failed to publish layer $layername, with codes $res0, $res1, $res2')");
    return "$createWorkspaceLog. Failed to publish layer $layername, with codes $res0, $res1, $res2";
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_publishGeoTIFF(text, text, text, text, text, text, text, text, text, text) IS 'Публикация GeoTIFF';

--------------------------
-- Публикация Shapefile --
--------------------------
CREATE OR REPLACE FUNCTION admin.ov_publishShapefile(text, text, text, text, text, text, text, text, text, text) RETURNS text AS $$
  my $processid    = $_[0] ne '' ? $_[0] : time;
  my $resourceid   = $_[1];
  my $workspace    = $_[2];
  my $layername    = $_[3];
  my $title        = $_[4];
  my $description  = $_[5];
  my $keywords     = $_[6];
  my $defaultstyle = $_[7];
  my $styles       = $_[8];
  my $pathtofile   = $_[9];
  my $stageStartTime = time;

  # Обязательные поля
  if ($workspace eq '' or $layername eq '' or $title eq '' or $defaultstyle eq '' or $pathtofile eq '') {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishShapefile', '$stageStartTime', '".time."', 'ERROR', 'Fill all required arguments')");
    return "Fill all required arguments";
  }

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }
  spi_exec_query("SELECT admin.ov_loginJOSSO('$processid')");

  # Обработка ключевых слов
  if ($keywords ne '') {
    $xml = '';
    @list = split(/,/, $keywords);
    foreach $keyword (@list) {$xml .= "<string>$keyword</string>";}
    $keywordsxml = "<keywords>$xml</keywords>";
  }

  # Обработка стилей
  if ($styles ne '') {
    $xml = '';
    $styles =~ s/\s+//g;
    @list = split(/,/, $styles);
    foreach $style (@list) {$xml .= "<style>$style</style>";}
    $stylesxml = "<styles>$xml</styles>";
  }  

  $rv = spi_exec_query("SELECT admin.ov_createWorkspace('$processid', '$workspace')");
  $createWorkspaceLog = $rv->{rows}[0]->{ov_createworkspace};

  my $response = `curl --location-trusted -s -o /dev/null -w "%{http_code}" -b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' $_SHARED{'geoserver'}/rest/layers/$workspace\:$layername`;
  if ($response eq '200') {
    spi_exec_query("SELECT admin.ov_removeLayer('$processid', '$workspace', '$layername')");
  }

  $cmd0 = "curl --location-trusted  -w \"%{http_code}\" " . 
          "-b /tmp/geoserver.txt -u '$_SHARED{'gsuser'}:$_SHARED{'gspass'}' " .
          "-XPUT -H 'Content-type: text/plain' " .
          "-d 'file://$pathtofile' " .
          "$_SHARED{'geoserver'}/rest/workspaces/$workspace/datastores/$layername/external.shp";
  $res0 = qx($cmd0);

#  spi_exec_query("SELECT admin.ov_reloadGeoserverNodes('$processid')");

  $rv = spi_exec_query("SELECT admin.ov_isLayerExists('$processid', '$workspace', '$layername')");
  $exists = $rv->{rows}[0]->{ov_islayerexists};

  if ($exists eq 't') {
    spi_exec_query("UPDATE admin.admin_table SET publishedonce = true WHERE resourceid = '$resourceid' AND type = 'sf'");
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishShapefile', '$stageStartTime', '".time."', 'INFO', 'Layer $layername published successfully')");
    return "$createWorkspaceLog. Layer $layername published successfully";
  }
  else {
    spi_exec_query("SELECT admin.ov_logEvent('$processid', '$resourceid', NULL, NULL, 'publishShapefile', '$stageStartTime', '".time."', 'ERROR', 'Failed to publish layer $layername, with codes $res0, $res1, $res2')");
    return "$createWorkspaceLog. Failed to publish layer $layername, with codes $res0, $res1, $res2";
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_publishShapefile(text, text, text, text, text, text, text, text, text, text) IS 'Публикация Shapefile';

-----------------------------------------------
-- Удаление ресурса описанного в admin_table --
-----------------------------------------------
CREATE OR REPLACE FUNCTION admin.ov_removeResource(text, text, text) RETURNS text AS $$
  $resourceid  = $_[0];
  $param       = $_[1];
  $type        = $_[2];

  if ($_SHARED{'version'} eq '') {
    spi_exec_query('SELECT admin.ov_initPLPerl()');
  }

  # Удаление точек
  if ($type eq 'pt') {
  }

  # Удаление изолиний
  elsif ($type eq 'ln') {
  }

  # Удаление поверхности
  elsif ($type eq 'sf') {
  }

  # Удаление трэков
  elsif ($type eq 'tr') {
  }

  # Удаление полигонов
  elsif ($type eq 'pl') {
  }
$$ LANGUAGE plperlu;
COMMENT ON FUNCTION admin.ov_removeResource(text, text, text) IS 'Удаление ресурса описанного в admin_table';