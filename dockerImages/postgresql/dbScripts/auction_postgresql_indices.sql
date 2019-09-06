--
-- Create indicies for auction tables
-- Run as auction user
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

CREATE INDEX auction_auctioneer_id_idx ON auction USING btree (auctioneer_id);
CREATE INDEX auction_starttime_idx ON auction USING btree (starttime);
CREATE INDEX auction_state_idx ON auction USING btree (state);
CREATE INDEX auction_current_activated_idx ON auction USING btree (current, activated);

CREATE INDEX auction_keyword_auction_idx ON auction_keyword USING btree (auction_id);
CREATE INDEX auction_keyword_keyword_idx ON auction_keyword USING btree (keyword_id);

CREATE INDEX highbid_preloaded_idx ON highbid USING btree (preloaded);
CREATE INDEX highbid_bidder_id_idx ON highbid USING btree (bidder_id);
CREATE INDEX highbid_item_id_idx ON highbid USING btree (item_id);
CREATE INDEX highbid_auction_id_idx ON highbid USING btree (auction_id);
CREATE INDEX highbid_state_idx ON highbid USING btree (state, id);
CREATE INDEX highbid_state_bidder_endtime_idx ON highbid USING btree (state, bidder_id, biddingendtime);

CREATE INDEX bidcompletiondelay_bid_id_idx ON bidcompletiondelay USING btree (bidid);
CREATE INDEX bidcompletiondelay_item_id_idx ON bidcompletiondelay USING btree (item_id);
CREATE INDEX bidcompletiondelay_auction_id_idx ON bidcompletiondelay USING btree (auction_id);

CREATE INDEX item_auction_id_idx ON item USING btree (auction_id);
CREATE INDEX item_highbid_id_idx ON item USING btree (highbid_id);
CREATE INDEX item_auctioneer_id_idx ON item USING btree (auctioneer_id);
CREATE INDEX item_auction_id_id_idx ON item USING btree (auction_id,id);
CREATE INDEX item_preloaded_idx ON item USING btree (preloaded);

CREATE INDEX user_authtoken_idx ON userdata USING btree (authtoken);
CREATE INDEX user_email_idx ON userdata USING btree (email);

CREATE INDEX keyword_keyword_idx ON keyword USING btree (keyword);

CREATE INDEX auction_keyword_keyword_idx ON auction_keyword USING btree (keyword_id);
CREATE INDEX auction_keyword_auction_idx ON auction_keyword USING btree (auction_id);

