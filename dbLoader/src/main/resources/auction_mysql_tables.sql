/* This script creates the schema for the Auction application
 *  when using MySQL.
 *
 * Last modified by: Hal Rosenberg
 */  

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

SHOW WARNINGS;

USE `auction` ;

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

-- -----------------------------------------------------
-- Table `auction`.`userdata`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `auction`.`userdata` (
  `id` BIGINT(20) NOT NULL,
  `authorities` VARCHAR(255) NULL DEFAULT NULL ,
  `creditlimit` FLOAT NULL DEFAULT NULL ,
  `email` VARCHAR(255) NOT NULL UNIQUE ,
  `loggedin` BIT(1) NOT NULL ,
  `enabled` BIT(1) NOT NULL ,
  `firstname` VARCHAR(40) NULL DEFAULT NULL ,
  `lastname` VARCHAR(80) NULL DEFAULT NULL ,
  `authtoken` VARCHAR(100) NULL DEFAULT NULL ,
  `password` VARCHAR(20) NULL DEFAULT NULL ,
  `state` VARCHAR(20) NOT NULL ,
  `version` INT(11) NULL DEFAULT NULL ,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

-- -----------------------------------------------------
-- Table `auction`.`highbid`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `auction`.`highbid` (
  `id` BIGINT(20) NOT NULL,
  `amount` FLOAT NULL DEFAULT NULL ,
  `state` VARCHAR(20) NULL DEFAULT NULL ,
  `bidcount` INT(11) NULL DEFAULT NULL ,
  `biddingendtime` DATETIME NULL DEFAULT NULL ,
  `biddingstarttime` DATETIME NULL DEFAULT NULL ,
  `currentbidtime` DATETIME NULL DEFAULT NULL ,
  `bidder_id` BIGINT(20) NULL DEFAULT NULL ,
  `auction_id` BIGINT(20) NOT NULL ,
  `item_id` BIGINT(20) NOT NULL ,
  `bidderid` BIGINT(20) NULL DEFAULT NULL ,
  `auctionid` BIGINT(20) NOT NULL ,
  `itemid` BIGINT(20) NOT NULL ,
  `bidid` VARCHAR(40) NULL DEFAULT NULL ,
  `preloaded` BIT NULL DEFAULT NULL ,
  `version` INT(11) NULL DEFAULT NULL ,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `auction`.`item`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `auction`.`item` (
  `id` BIGINT(20) NOT NULL,
  `dateoforigin` DATE NULL DEFAULT NULL ,
  `manufacturer` VARCHAR(100) NULL DEFAULT NULL ,
  `cond` VARCHAR(20) NULL DEFAULT NULL ,
  `shortdescription` VARCHAR(127) NULL DEFAULT NULL ,
  `longdescription` VARCHAR(1024) NULL DEFAULT NULL ,
  `startingbidamount` FLOAT NULL DEFAULT NULL ,
  `state` VARCHAR(20) NULL DEFAULT NULL ,
  `version` INT(11) NULL DEFAULT NULL ,
  `auctioneer_id` BIGINT(20) NULL DEFAULT NULL ,
  `auction_id` BIGINT(20) NULL DEFAULT NULL ,
  `highbid_id` BIGINT(20) NULL DEFAULT NULL ,
  `preloaded` BIT NULL DEFAULT NULL ,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `auction`.`auction`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `auction`.`auction` (
  `id` BIGINT(20) NOT NULL,
  `category` VARCHAR(40) NULL DEFAULT NULL ,
  `endtime` DATETIME NULL DEFAULT NULL ,
  `name` VARCHAR(100) NULL DEFAULT NULL ,
  `starttime` DATETIME NULL DEFAULT NULL ,
  `state` VARCHAR(20) NULL DEFAULT NULL ,
  `version` INT(11) NULL DEFAULT NULL ,
  `current` BIT NULL DEFAULT NULL ,
  `activated` BIT NULL DEFAULT NULL ,
  `auctioneer_id` BIGINT(20) NULL DEFAULT NULL ,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

-- -----------------------------------------------------
-- Table `auction`.`keyword`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `auction`.`keyword` (
  `id` BIGINT(20) NOT NULL,
  `keyword`  VARCHAR(64) NULL DEFAULT NULL ,
  `version` INT(11) NULL DEFAULT NULL ,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `auction`.`dbbenchmarkinfo`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `auction`.`dbbenchmarkinfo` (
  `id` BIGINT(20) NOT NULL,
  `maxusers` BIGINT(20) DEFAULT NULL,
  `maxduration` BIGINT(20) DEFAULT NULL,
  `numnosqlshards` BIGINT(20) DEFAULT NULL,
  `numnosqlreplicas` BIGINT(20) DEFAULT NULL,
  `imagestoretype` VARCHAR(20) NULL DEFAULT NULL ,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

-- -----------------------------------------------------
-- Table `auction`.`auctionmgmt`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `auction`.`auctionmgmt` (
  `id` BIGINT(20) NOT NULL,
  `masternodeid` BIGINT(20) DEFAULT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `auction`.`auction_keyword`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `auction`.`auction_keyword` (
  `auction_id` BIGINT(20) NOT NULL,
  `keyword_id` BIGINT(20) NOT NULL ,
  PRIMARY KEY (`auction_id`, `keyword_id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

--
-- Table structure for table `hibernate_sequences`
--
CREATE TABLE `hibernate_sequences` (
  `sequence_name` varchar(255) NOT NULL,
  `sequence_next_hi_value` int(11) DEFAULT NULL,
   PRIMARY KEY (`sequence_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- -----------------------------------------------------
-- Table `auction`.`bidcompletiondelay`
-- -----------------------------------------------------
SHOW WARNINGS;
CREATE  TABLE IF NOT EXISTS `auction`.`bidcompletiondelay` (
  `id` BIGINT(20) NOT NULL,
  `delay` BIGINT(20) NULL DEFAULT NULL ,
  `host` VARCHAR(255) NULL DEFAULT NULL ,
  `numcompletedbids` BIGINT(20) NULL DEFAULT NULL ,
  `timestamp` DATETIME NULL DEFAULT NULL ,
  `version` INT(11) NULL DEFAULT NULL ,
  `bidid` VARCHAR(40) NULL DEFAULT NULL ,
  `auction_id` BIGINT(20) NULL DEFAULT NULL ,
  `item_id` BIGINT(20) NULL DEFAULT NULL ,
  `biddingstate` VARCHAR(20) NULL DEFAULT NULL ,
  `bidtime` DATETIME NULL DEFAULT NULL ,
  `receivingnode` BIGINT(20) NULL DEFAULT NULL ,
  `completingnode` BIGINT(20) NULL DEFAULT NULL ,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

-- -----------------------------------------------------
-- Table `auction`.`fixedtimeoffset`
-- -----------------------------------------------------
SHOW WARNINGS;
CREATE  TABLE IF NOT EXISTS `auction`.`fixedtimeoffset` (
  `id` BIGINT(20) NOT NULL,
  `timeoffset` BIGINT(20),
  `version` INT(11) NULL DEFAULT NULL ,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
