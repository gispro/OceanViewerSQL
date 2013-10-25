--SELECT admin.ov_ssh('psql');
--SELECT admin.ov_ssh('RU_Hydrometcentre_122_2', 'g.region -p');
--SELECT admin.ov_lcc('RU_RIHMI-WDC_1196_p0056_03_ln');
--SELECT admin.ov_psql('SELECT admin.ov_pushInQueue(''128'', ''RU_Hydrometcentre_50'', ''p0001_00'', ''pt'')');

--SELECT admin.ov_initPlPerl();
--SELECT admin.ov_loginJOSSO();
--SELECT admin.ov_reloadGeoserverNodes();
--SELECT admin.ov_pushInQueue('128', 'RU_Hydrometcentre_50', 'p0001_00', 'pt');
--SELECT admin.ov_popFromQueue('128', 'RU_Hydrometcentre_50', 'p0001_00', 'pt');
--SELECT admin.ov_logEvent('123456', 'RU_Hydrometcentre_42_3', NULL, NULL, 'publishPostgis', '2013-09-04 13:00:00', '2013-09-04 13:38:00', 'DEBUG', 'test message');

--SELECT admin.ov_getSchema('RU_AARI_3151_1');
--SELECT admin.ov_getWorkspace('RU_Hydrometcentre_46_1');
--SELECT admin.ov_getLayername('RU_Hydrometcentre_46_1', '', 'pt');
--SELECT admin.ov_isLayerExists('RU_Hydrometcentre_46_1', '', 'pt');

--SELECT admin.ov_getLayerDefaultStyle('RU_Hydrometcentre_42_3', 'p0056_03', 'pt');
--SELECT admin.ov_getLayerStyles('RU_Hydrometcentre_42_3', 'p0056_03', 'pt');
--SELECT admin.ov_getLayerStylesXML('RU_Hydrometcentre_42_3', 'p0056_03', 'pt');
--SELECT admin.ov_getLayerKeywords('RU_Hydrometcentre_42_3');
--SELECT admin.ov_getLayerKeywordsXML('RU_Hydrometcentre_46_3');
--SELECT admin.ov_getLayerBBoxXML('RU_Hydrometcentre_46_1');
--SELECT admin.ov_getLayerGridXML('/opt/gis2/OceanViewer-grass/data/resources/surfaces/ru_hydrometcentre_61_p0239_00_sf.tif');
--SELECT admin.ov_getResourceDescription('RU_Hydrometcentre_46_1');
--SELECT admin.ov_getLayerTitle('RU_Hydrometcentre_46', 'p0056_03', 'sf');
--SELECT admin.ov_removeLayer('RU_Hydrometcentre_46_1', 'p0056_03', 'sf');
--SELECT admin.ov_updateLayerTitleInSavedMaps('RU_Hydrometcentre_46', 'p0056_03', 'pt');

--SELECT admin.ov_addGeometryColumn('', 'RU_AARI_3151_1');
--SELECT admin.ov_addPrimaryKey('123', 'RU_Hydrometcentre_42_3');
--SELECT admin.ov_createMask('RU_Hydrometcentre_46_1');
--SELECT admin.ov_createWorkspace('RU_Hydrometcentre_123_14');
--SELECT admin.ov_removeWorkspace('RU_Hydrometcentre_60');

--Public API
select admin.ov_processAllResources();
--SELECT admin.ov_processResource('', 'RU_AARI_3151_1', '', 'pt');
--SELECT admin.ov_processResource('processid', 'resourceid','param','type');

--SELECT admin.ov_publishResource('123', 'RU_Hydrometcentre_46', 'p0056_03', 'sf');
--SELECT admin.ov_publishPostgis('processid', 'resourceid', 'workspace', 'layername', 'title', 'description', 'keywords', 'defaultstyle', 'styles', 'schema', 'tablename');
--SELECT admin.ov_publishGeoTIFF('processid', 'resourceid', 'workspace', 'layername', 'title', 'description', 'keywords', 'defaultstyle', 'styles', '/path_to_geotiff');
--SELECT admin.ov_publishShapefile('processid', 'resourceid', 'workspace', 'layername', 'title', 'description', 'keywords', 'defaultstyle', 'styles', '/path_to_shapefile');

--SELECT admin.ov_createResource('', 'RU_AARI_3151_1', '', 'pt');
--SELECT admin.ov_createPoints('processid', 'RU_Hydrometcentre_61');
--SELECT admin.ov_createSurface('processid', 'RU_Hydrometcentre_60', 'p0239_00', '0.2');
--SELECT admin.ov_createIsolines('processid', 'resourceid', 'param', 'cellsize', 'step', 'minlevel', 'maxlevel');
--SELECT admin.ov_createTracks('processid', 'resourceid');
--SELECT admin.ov_createPolygons('processid', 'resourceid', 'param');

--SELECT admin.ov_removeResource('processid', 'resourceid', 'param', 'type');
--SELECT admin.ov_removeLayer('processid', 'resourceid', 'param', 'type');
--SELECT admin.ov_removeLayer('processid', 'workspace', 'layername');


--select * from admin.admin_table where resourceid ilike 'RU_Hydrometcentre_46';
--update admin.admin_table set resourceid = 'RU_Hydrometcentre_46_1' where resourceid = 'RU_Hydrometcentre_46'