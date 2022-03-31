SET NAMES utf8mb4;

CREATE TABLE `dataset` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `database` varchar(64) DEFAULT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `description` varchar(255) DEFAULT NULL,
  `from` varchar(255) NOT NULL DEFAULT '',
  `select` varchar(255) NOT NULL DEFAULT '',
  `group_by` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `filter` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `dataset_id` int(11) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `status` enum('disabled','hidden','visible','default','required') NOT NULL DEFAULT 'visible',
  `type` varchar(32) NOT NULL DEFAULT '',
  `where` varchar(1024) NOT NULL DEFAULT '',
  `join` varchar(256) NOT NULL DEFAULT '',
  `options` varchar(1024) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `grouping` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `dataset_id` int(10) unsigned NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `status` enum('disabled','hidden','visible','default') NOT NULL DEFAULT 'visible',
  `select` varchar(2048) DEFAULT NULL,
  `group_by` varchar(128) NOT NULL DEFAULT '',
  `join` varchar(256) DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `query` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `md5` varchar(64) DEFAULT '',
  `name` varchar(128) DEFAULT NULL,
  `user_id` int(11) unsigned DEFAULT NULL,
  `dataset_id` int(11) unsigned DEFAULT NULL,
  `editor` varchar(32) DEFAULT NULL,
  `params` MEDIUMBLOB  NULL DEFAULT NULL,
  `topic_id` int(10) unsigned DEFAULT NULL,
  `filters` varchar(256) DEFAULT NULL,
  `groupings` varchar(256) DEFAULT NULL,
  `date_last_exec` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_md5` (`md5`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_dataset_id` (`dataset_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `result` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `query_id` int(11) unsigned NOT NULL,
  `user_id` int(11) unsigned DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `statement` varchar(2048) DEFAULT NULL,
  `exec_time` decimal(5,2) unsigned DEFAULT NULL,
  `matrix` mediumblob,
  PRIMARY KEY (`id`),
  KEY `idx_query_id` (`query_id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `role` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `role_dataset` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `role_id` int(11) unsigned NOT NULL,
  `dataset_id` int(11) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `role_user` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `role_id` int(11) unsigned NOT NULL,
  `user_id` int(11) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `topic` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `dataset_id` int(11) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `status` enum('disabled','hidden','visible','default') NOT NULL DEFAULT 'visible',
  `select` varchar(512) NOT NULL DEFAULT '',
  `where` varchar(255) NOT NULL DEFAULT '',
  `group_by` varchar(255) NOT NULL DEFAULT '',
  `order_by` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `user` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(128) NOT NULL DEFAULT '',
  `first_name` varchar(64) DEFAULT NULL,
  `last_name` varchar(64) DEFAULT NULL,
  `status` enum('enabled','disabled') NOT NULL DEFAULT 'enabled',
  `type` enum('explorer','developer','admin') NOT NULL DEFAULT 'explorer',
  `picture_url` varchar(256) DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_last_active` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
