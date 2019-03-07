/*
Copyright (c) 2019 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*
CQL to create Cassandra keyspaces and tables for the Auction application
*/
DROP KEYSPACE IF EXISTS auction_event;
DROP KEYSPACE IF EXISTS auction_image;

CREATE KEYSPACE auction_event 
  WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 1 };

CREATE KEYSPACE auction_image 
  WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 1 };
  
CREATE TABLE auction_event.attendancerecord_by_userid (
  user_id bigint,
  record_time timestamp,
  auction_id bigint,
  state text,
  auction_name text,
  PRIMARY KEY ((user_id), record_time, auction_id)
  ) WITH CLUSTERING ORDER BY (record_time ASC, auction_id ASC);
  
CREATE TABLE auction_event.bid_by_bidderid (
  bidder_id bigint,
  bid_time timestamp,
  item_id bigint,
  amount float,
  state text,
  bid_id timeuuid,
  bid_count int,
  receiving_node bigint,
  auction_id bigint,
  PRIMARY KEY ((bidder_id), bid_time, item_id)
  ) WITH CLUSTERING ORDER BY (bid_time ASC, item_id ASC);
  
CREATE TABLE auction_event.nosql_benchmark_info (
  id timeuuid PRIMARY KEY,
  max_users bigint,
  imagestore_type text
  );
  
CREATE TABLE auction_event.imagestore_benchmark_info (
  id timeuuid PRIMARY KEY,
  max_users bigint,
  imagestore_type text
  );
 
CREATE TABLE auction_image.image_info (
  entity_type text,
  entity_id bigint,
  preloaded boolean,
  image_id timeuuid,
  name text,
  format text,
  imagenum bigint,
  dateadded timestamp,
  PRIMARY KEY ((entity_type, entity_id), preloaded)
  ) WITH CLUSTERING ORDER BY (preloaded DESC);
     
CREATE TABLE auction_image.image_full (
  image_id timeuuid,
  preloaded boolean,
  image blob,
  PRIMARY KEY ((image_id), preloaded)
  ) WITH CLUSTERING ORDER BY (preloaded DESC);
     
CREATE TABLE auction_image.image_preview (
  image_id timeuuid,
  preloaded boolean,
  image blob,
  PRIMARY KEY ((image_id), preloaded))
  WITH CLUSTERING ORDER BY (preloaded DESC);
     
CREATE TABLE auction_image.image_thumbnail (
  image_id timeuuid,
  preloaded boolean,
  image blob,
  PRIMARY KEY ((image_id), preloaded))
  WITH CLUSTERING ORDER BY (preloaded DESC);
     
  