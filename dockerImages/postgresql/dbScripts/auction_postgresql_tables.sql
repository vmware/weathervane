--
-- Run as auction user
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

DROP TABLE IF EXISTS attendancerecord cascade;
DROP TABLE IF EXISTS auction cascade;
DROP TABLE IF EXISTS auction_keyword cascade;
DROP TABLE IF EXISTS bidcompletiondelay cascade;
DROP TABLE IF EXISTS item cascade;
DROP TABLE IF EXISTS keyword cascade;
DROP TABLE IF EXISTS userdata cascade;
DROP TABLE IF EXISTS highbid cascade;
DROP TABLE IF EXISTS dbbenchmarkinfo cascade;
DROP TABLE IF EXISTS auctionmgmt cascade;
DROP TABLE IF EXISTS fixedtimeoffset cascade;
DROP TABLE IF EXISTS hibernate_sequences cascade;

--
-- Name: auction; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE auction (
    id bigint NOT NULL,
    category character varying(40),
    endtime timestamp without time zone,
    name character varying(100),
    starttime timestamp without time zone,
    state character varying(20),
    version integer,
    current boolean,
    activated boolean,
    auctioneer_id bigint
);


ALTER TABLE auction OWNER TO auction;

--
-- Name: auction_keyword; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE auction_keyword (
    auction_id bigint NOT NULL,
    keyword_id bigint NOT NULL
);

ALTER TABLE auction_keyword OWNER TO auction;

--
-- Name: highbid; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE highbid (
    id bigint NOT NULL,
   	amount real,
    state character varying(20),
    bidcount integer,
    biddingendtime timestamp without time zone,
    biddingstarttime timestamp without time zone,
    currentbidtime timestamp without time zone,
    auction_id bigint NOT NULL,
    item_id bigint NOT NULL,
    bidder_id bigint,
    auctionid bigint NOT NULL,
    itemid bigint NOT NULL,
    bidderid bigint,
    bidid character varying(40),
    preloaded boolean,
    version integer
);


ALTER TABLE highbid OWNER TO auction;


--
-- Name: item; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE item (
    id bigint NOT NULL,
    cond character varying(20),
    dateoforigin date,
    longdescription character varying(1024),
    manufacturer character varying(100),
    shortdescription character varying(127),
    startingbidamount real,
    state character varying(20),
    version integer,
    preloaded boolean,
    auction_id bigint,
    auctioneer_id bigint,
    highbid_id bigint
);

ALTER TABLE item OWNER TO auction;

--
-- Name: bidcompletiondelay; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE bidcompletiondelay (
    id bigint NOT NULL,
    delay bigint,
    host character varying(255),
    numcompletedbids bigint,
    "timestamp" timestamp without time zone,
    version integer,
    auction_id bigint,
    item_id bigint,
	biddingstate character varying(20),
    bidid character varying(40),
    "bidtime" timestamp without time zone,
    receivingnode bigint,
    completingnode bigint
);


ALTER TABLE bidcompletiondelay OWNER TO auction;

--
-- Name: fixedtimeoffset; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE fixedtimeoffset (
    id bigint NOT NULL,
    timeoffset bigint,
    version integer
    );


ALTER TABLE fixedtimeoffset OWNER TO auction;

--
-- Name: hibernate_sequences; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE hibernate_sequences (
    sequence_name character varying(255) NOT NULL,
    sequence_next_hi_value integer
);


ALTER TABLE hibernate_sequences OWNER TO auction;

--
-- Name: keyword; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE keyword (
    id bigint NOT NULL,
    keyword character varying(255),
    version integer
);


ALTER TABLE keyword OWNER TO auction;

--
-- Name: auctionmgmt; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE auctionmgmt (
    id bigint NOT NULL,
    masternodeid bigint
);


ALTER TABLE auctionmgmt OWNER TO auction;

--
-- Name: dbbenchmarkinfo; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE dbbenchmarkinfo (
    id bigint NOT NULL,
    maxusers bigint,
    maxduration bigint,
    numnosqlshards bigint,
    numnosqlreplicas bigint,
    imagestoretype character varying(20)
);


ALTER TABLE dbbenchmarkinfo OWNER TO auction;

--
-- Name: userdata; Type: TABLE; Schema: public; Owner: auction; Tablespace: 
--

CREATE TABLE userdata (
    id bigint NOT NULL,
    authtoken character varying(100),
    authorities character varying(255),
    creditlimit real,
    email character varying(255),
    loggedin boolean NOT NULL,
    enabled boolean NOT NULL,
    firstname character varying(40),
    lastname character varying(80),
    password character varying(20),
    state character varying(20),
    version integer
);


ALTER TABLE userdata OWNER TO auction;

--
-- Name: auction_keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY auction_keyword
    ADD CONSTRAINT auction_keyword_pkey PRIMARY KEY (auction_id, keyword_id);


--
-- Name: auction_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY auction
    ADD CONSTRAINT auction_pkey PRIMARY KEY (id);

--
-- Name: highbid_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY highbid
    ADD CONSTRAINT highbid_pkey PRIMARY KEY (id);


--
-- Name: bidcompletiondelay_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY bidcompletiondelay
    ADD CONSTRAINT bidcompletiondelay_pkey PRIMARY KEY (id);

    
--
-- Name: fixedtimeoffset_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY fixedtimeoffset
    ADD CONSTRAINT fixedtimeoffset_pkey PRIMARY KEY (id);


--
-- Name: item_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- Name: keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY keyword
    ADD CONSTRAINT keyword_pkey PRIMARY KEY (id);


--
-- Name: userdata_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY userdata
    ADD CONSTRAINT userdata_pkey PRIMARY KEY (id);

--
-- Name: dbbenchmarkinfo_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY dbbenchmarkinfo
    ADD CONSTRAINT dbbenchmarkinfo_pkey PRIMARY KEY (id);

--
-- Name: userdata_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY auctionmgmt
    ADD CONSTRAINT auctionmgmt_pkey PRIMARY KEY (id);
    
--
-- Name: hibernate_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: auction; Tablespace: 
--

ALTER TABLE ONLY hibernate_sequences
    ADD CONSTRAINT hibernate_sequences_pkey PRIMARY KEY (sequence_name);

