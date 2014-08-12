-- Table: admin.action_log

-- DROP TABLE admin.action_log;

CREATE TABLE admin.action_log
(
  id serial NOT NULL,
  datetime timestamp without time zone,
  login character varying(30),
  message character varying(255),
  CONSTRAINT action_log_pkey PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE admin.action_log
  OWNER TO esimo;

  
  -- Table: admin.ov_animation_catalog

-- DROP TABLE admin.ov_animation_catalog;

CREATE TABLE admin.ov_animation_catalog
(
  layers text,
  title character varying(50),
  url character varying(255),
  x_axis text,
  user_created character varying,
  user_modified character varying,
  date_created timestamp without time zone,
  date_modified timestamp without time zone,
  anim_id serial NOT NULL,
  CONSTRAINT ov_animation_catalog_pk PRIMARY KEY (anim_id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE admin.ov_animation_catalog
  OWNER TO esimo;

  -- Table: admin.ov_aqua_catalog

-- DROP TABLE admin.ov_aqua_catalog;

CREATE TABLE admin.ov_aqua_catalog
(
  id serial NOT NULL,
  name character varying,
  lon double precision,
  lat double precision,
  zoom integer,
  CONSTRAINT ov_aqua_catalog_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE admin.ov_aqua_catalog
  OWNER TO esimo;

  
  
  
  -- Table: admin.ov_arcgis_catalog

-- DROP TABLE admin.ov_arcgis_catalog;

CREATE TABLE admin.ov_arcgis_catalog
(
  id serial NOT NULL,
  title character varying,
  url character varying,
  format character varying(20),
  user_created character varying(20),
  user_modified character varying(20),
  date_created timestamp without time zone,
  date_modified timestamp without time zone,
  CONSTRAINT ov_arcgis_catalog_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE admin.ov_arcgis_catalog
  OWNER TO esimo;

  
  -- Table: admin.ov_charts_catalog

-- DROP TABLE admin.ov_charts_catalog;

CREATE TABLE admin.ov_charts_catalog
(
  layers text,
  name character varying(50),
  url character varying(255),
  x_axis text,
  y_axis text, -- 
  user_created character varying,
  user_modified character varying,
  date_created timestamp without time zone,
  date_modified timestamp without time zone,
  title character varying,
  chart_id serial NOT NULL,
  is_default boolean,
  CONSTRAINT ov_charts_catalog_pk PRIMARY KEY (chart_id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE admin.ov_charts_catalog
  OWNER TO esimo;
COMMENT ON COLUMN admin.ov_charts_catalog.y_axis IS '
';



-- Table: admin.ov_rss_catalog

-- DROP TABLE admin.ov_rss_catalog;

CREATE TABLE admin.ov_rss_catalog
(
  access character varying,
  icon character varying,
  name character varying,
  user_created character varying,
  title character varying,
  timer integer,
  url character varying,
  user_modified character varying,
  date_created timestamp without time zone,
  date_modified timestamp without time zone,
  id serial NOT NULL,
  CONSTRAINT ov_rss_catalog_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE admin.ov_rss_catalog
  OWNER TO esimo;

  
  
  
  -- Table: admin.ov_wms_catalog

-- DROP TABLE admin.ov_wms_catalog;

CREATE TABLE admin.ov_wms_catalog
(
  rest_url character varying,
  url character varying,
  server_name character varying,
  user_created character varying,
  user_modified character varying,
  date_created timestamp without time zone,
  date_modified timestamp without time zone,
  id serial NOT NULL,
  workspace character varying,
  CONSTRAINT ov_wms_catalog_id_pk PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE admin.ov_wms_catalog
  OWNER TO esimo;

  
  
  