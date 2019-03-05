--
-- Create primary key, foreign key, and other constraints for auction tables
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



ALTER TABLE ONLY item
    ADD CONSTRAINT fk_item_auction_id FOREIGN KEY (auction_id) REFERENCES auction(id);

ALTER TABLE ONLY item
    ADD CONSTRAINT fk_item_highbid_id FOREIGN KEY (highbid_id) REFERENCES highbid(id);

ALTER TABLE ONLY item
    ADD CONSTRAINT fk_item_auctioneer_id FOREIGN KEY (auctioneer_id) REFERENCES userdata(id);

ALTER TABLE ONLY highbid
    ADD CONSTRAINT fk_highbid_bidder_id FOREIGN KEY (bidder_id) REFERENCES userdata(id);

ALTER TABLE ONLY highbid
    ADD CONSTRAINT fk_highbid_item_id FOREIGN KEY (item_id) REFERENCES item(id);

ALTER TABLE ONLY highbid
    ADD CONSTRAINT fk_highbid_auction_id FOREIGN KEY (auction_id) REFERENCES auction(id);


ALTER TABLE ONLY auction
    ADD CONSTRAINT fk_auction_auctioneer_id FOREIGN KEY (auctioneer_id) REFERENCES userdata(id);

ALTER TABLE ONLY bidcompletiondelay
    ADD CONSTRAINT fk_bcd_auction_id FOREIGN KEY (auction_id) REFERENCES auction(id);
ALTER TABLE ONLY bidcompletiondelay
    ADD CONSTRAINT fk_bcd_item_id FOREIGN KEY (item_id) REFERENCES item(id);


    
ALTER TABLE ONLY auction_keyword
    ADD CONSTRAINT fk_auction_keyword_keyword_id FOREIGN KEY (keyword_id) REFERENCES keyword(id);

ALTER TABLE ONLY auction_keyword
    ADD CONSTRAINT fk_auction_keyword_auction_id FOREIGN KEY (auction_id) REFERENCES auction(id);



