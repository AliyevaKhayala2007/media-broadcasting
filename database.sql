-- =====================================================================
-- database.sql - OTT Media-Broadcasting OLTP model, consolidated DDL
-- GENERATED from ddl/00_*.sql .. ddl/09_*.sql by `uv run ott-build-sql`.
-- Do not edit by hand: change the files in ddl/ and regenerate.
--
--   psql -v ON_ERROR_STOP=1 -d <database> -f database.sql
-- =====================================================================
BEGIN;

-- >>>>> 00_schemas_and_types.sql
-- =====================================================================
-- 00_schemas_and_types.sql
-- OTT Media-Broadcasting OLTP model - schemas and ENUM types
-- Target: PostgreSQL 13+ (gen_random_uuid() is built in from v13)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Schemas (one per business domain)
-- ---------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS ref;         -- shared reference data
CREATE SCHEMA IF NOT EXISTS partner;     -- studios, distributors, agencies
CREATE SCHEMA IF NOT EXISTS content;     -- catalog, assets, live channels, EPG
CREATE SCHEMA IF NOT EXISTS talent;      -- people, credits, contracts, residuals
CREATE SCHEMA IF NOT EXISTS rights;      -- licensing, windows, royalties
CREATE SCHEMA IF NOT EXISTS subscriber;  -- accounts, profiles, devices
CREATE SCHEMA IF NOT EXISTS billing;     -- plans, subscriptions, TVOD, invoices, payments
CREATE SCHEMA IF NOT EXISTS playback;    -- viewing sessions, resume points, watchlist
CREATE SCHEMA IF NOT EXISTS adsales;     -- advertisers, campaigns, ad delivery

-- ---------------------------------------------------------------------
-- ref
-- ---------------------------------------------------------------------
CREATE TYPE ref.video_quality AS ENUM ('sd', 'hd', 'fhd', 'uhd_4k');
CREATE TYPE ref.monetization_model AS ENUM ('svod', 'avod', 'tvod');

-- ---------------------------------------------------------------------
-- partner
-- ---------------------------------------------------------------------
CREATE TYPE partner.partner_type AS ENUM
    ('studio', 'distributor', 'production_company', 'network', 'talent_agency', 'ad_agency', 'other');

-- ---------------------------------------------------------------------
-- content
-- ---------------------------------------------------------------------
CREATE TYPE content.title_type   AS ENUM ('movie', 'series', 'live_event', 'extra');
CREATE TYPE content.extra_type   AS ENUM ('trailer', 'teaser', 'behind_the_scenes', 'featurette', 'clip');
CREATE TYPE content.title_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE content.asset_kind   AS ENUM ('vod', 'live_stream');
CREATE TYPE content.audio_layout AS ENUM ('mono', 'stereo', 'surround_5_1', 'surround_7_1', 'atmos');
CREATE TYPE content.subtitle_kind AS ENUM ('subtitle', 'closed_caption', 'sdh', 'forced');

-- ---------------------------------------------------------------------
-- talent
-- ---------------------------------------------------------------------
CREATE TYPE talent.contract_status   AS ENUM ('draft', 'active', 'completed', 'terminated');
CREATE TYPE talent.compensation_type AS ENUM ('flat_fee', 'per_episode', 'backend_percentage', 'residual_percentage');
CREATE TYPE talent.residual_status   AS ENUM ('pending', 'paid', 'cancelled');

-- ---------------------------------------------------------------------
-- rights
-- ---------------------------------------------------------------------
CREATE TYPE rights.agreement_status AS ENUM ('draft', 'active', 'expired', 'terminated');
CREATE TYPE rights.royalty_basis    AS ENUM ('flat_fee', 'revenue_share', 'per_view', 'minimum_guarantee');
CREATE TYPE rights.statement_status AS ENUM ('draft', 'issued', 'paid', 'disputed');

-- ---------------------------------------------------------------------
-- subscriber
-- ---------------------------------------------------------------------
CREATE TYPE subscriber.account_status AS ENUM ('active', 'suspended', 'closed');
CREATE TYPE subscriber.address_type   AS ENUM ('billing', 'service');
CREATE TYPE subscriber.device_type    AS ENUM
    ('smart_tv', 'mobile', 'tablet', 'web_browser', 'streaming_stick', 'game_console', 'set_top_box');

-- ---------------------------------------------------------------------
-- billing
-- ---------------------------------------------------------------------
CREATE TYPE billing.billing_period      AS ENUM ('monthly', 'quarterly', 'annual');
CREATE TYPE billing.subscription_status AS ENUM ('trialing', 'active', 'past_due', 'paused', 'cancelled', 'expired');
CREATE TYPE billing.discount_type       AS ENUM ('percentage', 'fixed_amount', 'free_period');
CREATE TYPE billing.payment_method_type AS ENUM ('card', 'digital_wallet', 'bank_account', 'carrier_billing');
CREATE TYPE billing.invoice_status      AS ENUM ('draft', 'issued', 'paid', 'void', 'uncollectible');
CREATE TYPE billing.invoice_line_type   AS ENUM ('subscription', 'tvod', 'discount', 'adjustment');
CREATE TYPE billing.payment_status      AS ENUM ('pending', 'succeeded', 'failed', 'refunded', 'partially_refunded');
CREATE TYPE billing.refund_status       AS ENUM ('pending', 'succeeded', 'failed');
CREATE TYPE billing.tvod_type           AS ENUM ('rent', 'buy');

-- ---------------------------------------------------------------------
-- adsales
-- ---------------------------------------------------------------------
CREATE TYPE adsales.campaign_status    AS ENUM ('draft', 'active', 'paused', 'completed', 'cancelled');
CREATE TYPE adsales.io_status          AS ENUM ('draft', 'signed', 'cancelled');
CREATE TYPE adsales.pricing_model      AS ENUM ('cpm', 'cpcv', 'flat_fee');
CREATE TYPE adsales.creative_format    AS ENUM ('video', 'display', 'overlay');
CREATE TYPE adsales.approval_status    AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE adsales.break_position     AS ENUM ('pre_roll', 'mid_roll', 'post_roll');
CREATE TYPE adsales.targeting_type     AS ENUM ('country', 'genre', 'title', 'device_type');

-- >>>>> 01_ref.sql
-- =====================================================================
-- 01_ref.sql - shared reference data
-- Convention for every table:
--   * <table>_id UUID primary key, default gen_random_uuid()
--   * is_deleted / deleted_at soft-delete pair, kept consistent by a CHECK
--   * business (alternate) keys are partial UNIQUE indexes WHERE NOT is_deleted
-- =====================================================================

CREATE TABLE ref.currency (
    currency_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    iso_code        CHAR(3)      NOT NULL,              -- ISO 4217, e.g. USD
    currency_name   VARCHAR(100) NOT NULL,
    minor_unit      SMALLINT     NOT NULL DEFAULT 2,    -- number of decimal places
    is_deleted      BOOLEAN      NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_currency PRIMARY KEY (currency_id),
    CONSTRAINT ck_currency_iso CHECK (iso_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_currency_minor_unit CHECK (minor_unit BETWEEN 0 AND 4),
    CONSTRAINT ck_currency_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_currency_iso ON ref.currency (iso_code) WHERE NOT is_deleted;

CREATE TABLE ref.language (
    language_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    language_code   VARCHAR(12)  NOT NULL,              -- BCP 47 tag, e.g. en, en-US, pt-BR
    language_name   VARCHAR(100) NOT NULL,
    is_deleted      BOOLEAN      NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_language PRIMARY KEY (language_id),
    CONSTRAINT ck_language_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_language_code ON ref.language (language_code) WHERE NOT is_deleted;

CREATE TABLE ref.country (
    country_id          UUID         NOT NULL DEFAULT gen_random_uuid(),
    iso_alpha2          CHAR(2)      NOT NULL,          -- ISO 3166-1 alpha-2
    iso_alpha3          CHAR(3)      NOT NULL,          -- ISO 3166-1 alpha-3
    country_name        VARCHAR(100) NOT NULL,
    default_currency_id UUID         NOT NULL,
    is_deleted          BOOLEAN      NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_country PRIMARY KEY (country_id),
    CONSTRAINT fk_country_currency FOREIGN KEY (default_currency_id) REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_country_alpha2 CHECK (iso_alpha2 ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_country_alpha3 CHECK (iso_alpha3 ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_country_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_country_alpha2 ON ref.country (iso_alpha2) WHERE NOT is_deleted;
CREATE UNIQUE INDEX uq_country_alpha3 ON ref.country (iso_alpha3) WHERE NOT is_deleted;
CREATE INDEX ix_country_currency ON ref.country (default_currency_id);

-- A territory is a named group of countries used in rights deals (e.g. "MENA", "DACH", "Worldwide").
CREATE TABLE ref.territory (
    territory_id    UUID         NOT NULL DEFAULT gen_random_uuid(),
    territory_code  VARCHAR(20)  NOT NULL,
    territory_name  VARCHAR(100) NOT NULL,
    is_deleted      BOOLEAN      NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_territory PRIMARY KEY (territory_id),
    CONSTRAINT ck_territory_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_territory_code ON ref.territory (territory_code) WHERE NOT is_deleted;

CREATE TABLE ref.territory_country (
    territory_country_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    territory_id         UUID        NOT NULL,
    country_id           UUID        NOT NULL,
    is_deleted           BOOLEAN     NOT NULL DEFAULT false,
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT pk_territory_country PRIMARY KEY (territory_country_id),
    CONSTRAINT fk_territory_country_territory FOREIGN KEY (territory_id) REFERENCES ref.territory (territory_id),
    CONSTRAINT fk_territory_country_country   FOREIGN KEY (country_id)   REFERENCES ref.country (country_id),
    CONSTRAINT ck_territory_country_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_territory_country ON ref.territory_country (territory_id, country_id) WHERE NOT is_deleted;
CREATE INDEX ix_territory_country_country ON ref.territory_country (country_id);

-- >>>>> 02_partner.sql
-- =====================================================================
-- 02_partner.sql - external organizations (studios, distributors, agencies)
-- =====================================================================

CREATE TABLE partner.partner (
    partner_id      UUID                 NOT NULL DEFAULT gen_random_uuid(),
    partner_code    VARCHAR(30)          NOT NULL,
    legal_name      VARCHAR(200)         NOT NULL,
    partner_type    partner.partner_type NOT NULL,
    country_id      UUID                 NOT NULL,      -- country of registration
    tax_identifier  VARCHAR(50),
    website_url     VARCHAR(500),
    is_deleted      BOOLEAN              NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_partner PRIMARY KEY (partner_id),
    CONSTRAINT fk_partner_country FOREIGN KEY (country_id) REFERENCES ref.country (country_id),
    CONSTRAINT ck_partner_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_partner_code ON partner.partner (partner_code) WHERE NOT is_deleted;
CREATE INDEX ix_partner_country ON partner.partner (country_id);
CREATE INDEX ix_partner_type ON partner.partner (partner_type);

CREATE TABLE partner.partner_contact (
    partner_contact_id UUID         NOT NULL DEFAULT gen_random_uuid(),
    partner_id         UUID         NOT NULL,
    full_name          VARCHAR(200) NOT NULL,
    job_title          VARCHAR(100),
    email              VARCHAR(320),
    phone              VARCHAR(30),
    is_primary         BOOLEAN      NOT NULL DEFAULT false,
    is_deleted         BOOLEAN      NOT NULL DEFAULT false,
    deleted_at         TIMESTAMPTZ,
    CONSTRAINT pk_partner_contact PRIMARY KEY (partner_contact_id),
    CONSTRAINT fk_partner_contact_partner FOREIGN KEY (partner_id) REFERENCES partner.partner (partner_id),
    CONSTRAINT ck_partner_contact_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_partner_contact_partner ON partner.partner_contact (partner_id);
-- at most one primary contact per partner
CREATE UNIQUE INDEX uq_partner_contact_primary ON partner.partner_contact (partner_id)
    WHERE is_primary AND NOT is_deleted;

-- >>>>> 03_content.sql
-- =====================================================================
-- 03_content.sql - catalog, localization, maturity ratings, media assets,
--                  live channels and EPG
-- =====================================================================

-- ---------------------------------------------------------------------
-- Genre
-- ---------------------------------------------------------------------
CREATE TABLE content.genre (
    genre_id    UUID         NOT NULL DEFAULT gen_random_uuid(),
    genre_code  VARCHAR(30)  NOT NULL,
    genre_name  VARCHAR(100) NOT NULL,
    is_deleted  BOOLEAN      NOT NULL DEFAULT false,
    deleted_at  TIMESTAMPTZ,
    CONSTRAINT pk_genre PRIMARY KEY (genre_id),
    CONSTRAINT ck_genre_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_genre_code ON content.genre (genre_code) WHERE NOT is_deleted;

-- ---------------------------------------------------------------------
-- Title: movie, series, live event or extra (trailer, featurette ...)
-- ---------------------------------------------------------------------
CREATE TABLE content.title (
    title_id                UUID                 NOT NULL DEFAULT gen_random_uuid(),
    title_type              content.title_type   NOT NULL,
    original_name           VARCHAR(300)         NOT NULL,
    original_language_id    UUID                 NOT NULL,
    production_country_id   UUID,
    release_year            SMALLINT,
    runtime_minutes         SMALLINT,              -- movies / extras; NULL for series
    title_status            content.title_status NOT NULL DEFAULT 'draft',
    parent_title_id         UUID,                  -- extras only: the title the extra belongs to
    extra_type              content.extra_type,    -- extras only
    event_start_at          TIMESTAMPTZ,           -- live events only
    event_end_at            TIMESTAMPTZ,           -- live events only
    is_deleted              BOOLEAN              NOT NULL DEFAULT false,
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT pk_title PRIMARY KEY (title_id),
    CONSTRAINT fk_title_language FOREIGN KEY (original_language_id)  REFERENCES ref.language (language_id),
    CONSTRAINT fk_title_country  FOREIGN KEY (production_country_id) REFERENCES ref.country (country_id),
    CONSTRAINT fk_title_parent   FOREIGN KEY (parent_title_id)       REFERENCES content.title (title_id),
    CONSTRAINT ck_title_release_year CHECK (release_year BETWEEN 1888 AND 2200),
    CONSTRAINT ck_title_runtime CHECK (runtime_minutes > 0),
    CONSTRAINT ck_title_extra CHECK (
        (title_type = 'extra' AND parent_title_id IS NOT NULL AND extra_type IS NOT NULL)
        OR (title_type <> 'extra' AND parent_title_id IS NULL AND extra_type IS NULL)),
    CONSTRAINT ck_title_live_event CHECK (
        (title_type = 'live_event' AND event_start_at IS NOT NULL)
        OR (title_type <> 'live_event' AND event_start_at IS NULL AND event_end_at IS NULL)),
    CONSTRAINT ck_title_event_range CHECK (event_end_at IS NULL OR event_end_at > event_start_at),
    CONSTRAINT ck_title_series_runtime CHECK (title_type <> 'series' OR runtime_minutes IS NULL),
    CONSTRAINT ck_title_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_title_type_status ON content.title (title_type, title_status) WHERE NOT is_deleted;
CREATE INDEX ix_title_language ON content.title (original_language_id);
CREATE INDEX ix_title_country ON content.title (production_country_id);
CREATE INDEX ix_title_parent ON content.title (parent_title_id);

CREATE TABLE content.title_localization (
    title_localization_id UUID          NOT NULL DEFAULT gen_random_uuid(),
    title_id              UUID          NOT NULL,
    language_id           UUID          NOT NULL,
    localized_name        VARCHAR(300)  NOT NULL,
    short_synopsis        VARCHAR(500),
    long_synopsis         TEXT,
    is_deleted            BOOLEAN       NOT NULL DEFAULT false,
    deleted_at            TIMESTAMPTZ,
    CONSTRAINT pk_title_localization PRIMARY KEY (title_localization_id),
    CONSTRAINT fk_title_localization_title    FOREIGN KEY (title_id)    REFERENCES content.title (title_id),
    CONSTRAINT fk_title_localization_language FOREIGN KEY (language_id) REFERENCES ref.language (language_id),
    CONSTRAINT ck_title_localization_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_title_localization ON content.title_localization (title_id, language_id) WHERE NOT is_deleted;
CREATE INDEX ix_title_localization_language ON content.title_localization (language_id);

CREATE TABLE content.title_genre (
    title_genre_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    title_id       UUID        NOT NULL,
    genre_id       UUID        NOT NULL,
    is_primary     BOOLEAN     NOT NULL DEFAULT false,
    is_deleted     BOOLEAN     NOT NULL DEFAULT false,
    deleted_at     TIMESTAMPTZ,
    CONSTRAINT pk_title_genre PRIMARY KEY (title_genre_id),
    CONSTRAINT fk_title_genre_title FOREIGN KEY (title_id) REFERENCES content.title (title_id),
    CONSTRAINT fk_title_genre_genre FOREIGN KEY (genre_id) REFERENCES content.genre (genre_id),
    CONSTRAINT ck_title_genre_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_title_genre ON content.title_genre (title_id, genre_id) WHERE NOT is_deleted;
CREATE UNIQUE INDEX uq_title_genre_primary ON content.title_genre (title_id) WHERE is_primary AND NOT is_deleted;
CREATE INDEX ix_title_genre_genre ON content.title_genre (genre_id);

-- ---------------------------------------------------------------------
-- Series structure
-- ---------------------------------------------------------------------
CREATE TABLE content.season (
    season_id      UUID         NOT NULL DEFAULT gen_random_uuid(),
    title_id       UUID         NOT NULL,      -- the series (title_type = 'series')
    season_number  SMALLINT     NOT NULL,
    season_name    VARCHAR(300),
    release_year   SMALLINT,
    is_deleted     BOOLEAN      NOT NULL DEFAULT false,
    deleted_at     TIMESTAMPTZ,
    CONSTRAINT pk_season PRIMARY KEY (season_id),
    CONSTRAINT fk_season_title FOREIGN KEY (title_id) REFERENCES content.title (title_id),
    CONSTRAINT ck_season_number CHECK (season_number >= 0),
    CONSTRAINT ck_season_release_year CHECK (release_year BETWEEN 1888 AND 2200),
    CONSTRAINT ck_season_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_season_number ON content.season (title_id, season_number) WHERE NOT is_deleted;

CREATE TABLE content.episode (
    episode_id       UUID         NOT NULL DEFAULT gen_random_uuid(),
    season_id        UUID         NOT NULL,
    episode_number   SMALLINT     NOT NULL,
    original_name    VARCHAR(300) NOT NULL,
    runtime_minutes  SMALLINT,
    original_air_date DATE,
    is_deleted       BOOLEAN      NOT NULL DEFAULT false,
    deleted_at       TIMESTAMPTZ,
    CONSTRAINT pk_episode PRIMARY KEY (episode_id),
    CONSTRAINT fk_episode_season FOREIGN KEY (season_id) REFERENCES content.season (season_id),
    CONSTRAINT ck_episode_number CHECK (episode_number > 0),
    CONSTRAINT ck_episode_runtime CHECK (runtime_minutes > 0),
    CONSTRAINT ck_episode_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_episode_number ON content.episode (season_id, episode_number) WHERE NOT is_deleted;

CREATE TABLE content.episode_localization (
    episode_localization_id UUID         NOT NULL DEFAULT gen_random_uuid(),
    episode_id              UUID         NOT NULL,
    language_id             UUID         NOT NULL,
    localized_name          VARCHAR(300) NOT NULL,
    synopsis                TEXT,
    is_deleted              BOOLEAN      NOT NULL DEFAULT false,
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT pk_episode_localization PRIMARY KEY (episode_localization_id),
    CONSTRAINT fk_episode_localization_episode  FOREIGN KEY (episode_id)  REFERENCES content.episode (episode_id),
    CONSTRAINT fk_episode_localization_language FOREIGN KEY (language_id) REFERENCES ref.language (language_id),
    CONSTRAINT ck_episode_localization_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_episode_localization ON content.episode_localization (episode_id, language_id) WHERE NOT is_deleted;
CREATE INDEX ix_episode_localization_language ON content.episode_localization (language_id);

-- ---------------------------------------------------------------------
-- Maturity ratings (per country rating board)
-- ---------------------------------------------------------------------
CREATE TABLE content.rating_board (
    rating_board_id UUID         NOT NULL DEFAULT gen_random_uuid(),
    board_code      VARCHAR(20)  NOT NULL,      -- e.g. MPA, BBFC, FSK
    board_name      VARCHAR(200) NOT NULL,
    country_id      UUID         NOT NULL,
    is_deleted      BOOLEAN      NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_rating_board PRIMARY KEY (rating_board_id),
    CONSTRAINT fk_rating_board_country FOREIGN KEY (country_id) REFERENCES ref.country (country_id),
    CONSTRAINT ck_rating_board_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_rating_board_code ON content.rating_board (board_code) WHERE NOT is_deleted;
CREATE INDEX ix_rating_board_country ON content.rating_board (country_id);

CREATE TABLE content.maturity_rating (
    maturity_rating_id UUID         NOT NULL DEFAULT gen_random_uuid(),
    rating_board_id    UUID         NOT NULL,
    rating_code        VARCHAR(20)  NOT NULL,   -- e.g. PG-13, 15, FSK 16
    min_age            SMALLINT     NOT NULL,   -- normalized minimum viewer age, compared with profile.max_age_rating
    description        VARCHAR(500),
    is_deleted         BOOLEAN      NOT NULL DEFAULT false,
    deleted_at         TIMESTAMPTZ,
    CONSTRAINT pk_maturity_rating PRIMARY KEY (maturity_rating_id),
    -- target of the composite FK from title_maturity_rating
    CONSTRAINT uq_maturity_rating_board UNIQUE (maturity_rating_id, rating_board_id),
    CONSTRAINT fk_maturity_rating_board FOREIGN KEY (rating_board_id) REFERENCES content.rating_board (rating_board_id),
    CONSTRAINT ck_maturity_rating_min_age CHECK (min_age BETWEEN 0 AND 21),
    CONSTRAINT ck_maturity_rating_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_maturity_rating_code ON content.maturity_rating (rating_board_id, rating_code) WHERE NOT is_deleted;

-- rating_board_id is carried here (via composite FK) so that a title gets at most one rating per board/country.
CREATE TABLE content.title_maturity_rating (
    title_maturity_rating_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    title_id                 UUID        NOT NULL,
    maturity_rating_id       UUID        NOT NULL,
    rating_board_id          UUID        NOT NULL,
    content_descriptors      VARCHAR(500),          -- e.g. "violence, strong language"
    is_deleted               BOOLEAN     NOT NULL DEFAULT false,
    deleted_at               TIMESTAMPTZ,
    CONSTRAINT pk_title_maturity_rating PRIMARY KEY (title_maturity_rating_id),
    CONSTRAINT fk_title_maturity_rating_title  FOREIGN KEY (title_id) REFERENCES content.title (title_id),
    CONSTRAINT fk_title_maturity_rating_rating FOREIGN KEY (maturity_rating_id, rating_board_id)
        REFERENCES content.maturity_rating (maturity_rating_id, rating_board_id),
    CONSTRAINT ck_title_maturity_rating_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_title_maturity_rating ON content.title_maturity_rating (title_id, rating_board_id) WHERE NOT is_deleted;
CREATE INDEX ix_title_maturity_rating_rating ON content.title_maturity_rating (maturity_rating_id, rating_board_id);

-- ---------------------------------------------------------------------
-- Live channels and EPG
-- ---------------------------------------------------------------------
CREATE TABLE content.live_channel (
    live_channel_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    channel_code        VARCHAR(30)  NOT NULL,
    channel_name        VARCHAR(200) NOT NULL,
    primary_language_id UUID         NOT NULL,
    is_ad_supported     BOOLEAN      NOT NULL DEFAULT false,
    is_deleted          BOOLEAN      NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_live_channel PRIMARY KEY (live_channel_id),
    CONSTRAINT fk_live_channel_language FOREIGN KEY (primary_language_id) REFERENCES ref.language (language_id),
    CONSTRAINT ck_live_channel_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_live_channel_code ON content.live_channel (channel_code) WHERE NOT is_deleted;
CREATE INDEX ix_live_channel_language ON content.live_channel (primary_language_id);

CREATE TABLE content.epg_schedule_entry (
    epg_schedule_entry_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    live_channel_id       UUID        NOT NULL,
    title_id              UUID,                    -- movie / live event / series-level airing
    episode_id            UUID,                    -- specific episode airing
    scheduled_start_at    TIMESTAMPTZ NOT NULL,
    scheduled_end_at      TIMESTAMPTZ NOT NULL,
    is_live               BOOLEAN     NOT NULL DEFAULT false,
    is_premiere           BOOLEAN     NOT NULL DEFAULT false,
    is_deleted            BOOLEAN     NOT NULL DEFAULT false,
    deleted_at            TIMESTAMPTZ,
    CONSTRAINT pk_epg_schedule_entry PRIMARY KEY (epg_schedule_entry_id),
    CONSTRAINT fk_epg_schedule_entry_channel FOREIGN KEY (live_channel_id) REFERENCES content.live_channel (live_channel_id),
    CONSTRAINT fk_epg_schedule_entry_title   FOREIGN KEY (title_id)        REFERENCES content.title (title_id),
    CONSTRAINT fk_epg_schedule_entry_episode FOREIGN KEY (episode_id)      REFERENCES content.episode (episode_id),
    CONSTRAINT ck_epg_schedule_entry_program CHECK (num_nonnulls(title_id, episode_id) = 1),
    CONSTRAINT ck_epg_schedule_entry_range CHECK (scheduled_end_at > scheduled_start_at),
    CONSTRAINT ck_epg_schedule_entry_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_epg_schedule_entry_start ON content.epg_schedule_entry (live_channel_id, scheduled_start_at) WHERE NOT is_deleted;
CREATE INDEX ix_epg_schedule_entry_title ON content.epg_schedule_entry (title_id);
CREATE INDEX ix_epg_schedule_entry_episode ON content.epg_schedule_entry (episode_id);

-- ---------------------------------------------------------------------
-- Media assets: the playable item (VOD file or live stream) and its tracks
-- ---------------------------------------------------------------------
CREATE TABLE content.media_asset (
    media_asset_id    UUID               NOT NULL DEFAULT gen_random_uuid(),
    title_id          UUID,               -- movie, live event or extra
    episode_id        UUID,               -- series episode
    live_channel_id   UUID,               -- 24/7 live channel stream
    asset_kind        content.asset_kind NOT NULL,
    version_label     VARCHAR(50)        NOT NULL DEFAULT 'original',  -- e.g. original, directors_cut
    duration_seconds  INTEGER,            -- NULL for live streams
    max_video_quality ref.video_quality  NOT NULL,
    manifest_url      VARCHAR(1000)      NOT NULL,                     -- HLS/DASH manifest
    is_drm_protected  BOOLEAN            NOT NULL DEFAULT true,
    is_deleted        BOOLEAN            NOT NULL DEFAULT false,
    deleted_at        TIMESTAMPTZ,
    CONSTRAINT pk_media_asset PRIMARY KEY (media_asset_id),
    CONSTRAINT fk_media_asset_title   FOREIGN KEY (title_id)        REFERENCES content.title (title_id),
    CONSTRAINT fk_media_asset_episode FOREIGN KEY (episode_id)      REFERENCES content.episode (episode_id),
    CONSTRAINT fk_media_asset_channel FOREIGN KEY (live_channel_id) REFERENCES content.live_channel (live_channel_id),
    CONSTRAINT ck_media_asset_owner CHECK (num_nonnulls(title_id, episode_id, live_channel_id) = 1),
    CONSTRAINT ck_media_asset_duration CHECK (
        (asset_kind = 'vod' AND duration_seconds IS NOT NULL AND duration_seconds > 0) OR (asset_kind = 'live_stream' AND duration_seconds IS NULL)),
    CONSTRAINT ck_media_asset_channel_live CHECK (live_channel_id IS NULL OR asset_kind = 'live_stream'),
    CONSTRAINT ck_media_asset_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_media_asset_title_version   ON content.media_asset (title_id, version_label)        WHERE title_id IS NOT NULL AND NOT is_deleted;
CREATE UNIQUE INDEX uq_media_asset_episode_version ON content.media_asset (episode_id, version_label)      WHERE episode_id IS NOT NULL AND NOT is_deleted;
CREATE UNIQUE INDEX uq_media_asset_channel_version ON content.media_asset (live_channel_id, version_label) WHERE live_channel_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX ix_media_asset_title ON content.media_asset (title_id);
CREATE INDEX ix_media_asset_episode ON content.media_asset (episode_id);
CREATE INDEX ix_media_asset_channel ON content.media_asset (live_channel_id);

CREATE TABLE content.audio_track (
    audio_track_id         UUID                 NOT NULL DEFAULT gen_random_uuid(),
    media_asset_id         UUID                 NOT NULL,
    language_id            UUID                 NOT NULL,
    audio_layout           content.audio_layout NOT NULL,
    is_original_language   BOOLEAN              NOT NULL DEFAULT false,
    is_audio_description   BOOLEAN              NOT NULL DEFAULT false,
    is_deleted             BOOLEAN              NOT NULL DEFAULT false,
    deleted_at             TIMESTAMPTZ,
    CONSTRAINT pk_audio_track PRIMARY KEY (audio_track_id),
    CONSTRAINT fk_audio_track_asset    FOREIGN KEY (media_asset_id) REFERENCES content.media_asset (media_asset_id),
    CONSTRAINT fk_audio_track_language FOREIGN KEY (language_id)    REFERENCES ref.language (language_id),
    CONSTRAINT ck_audio_track_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_audio_track ON content.audio_track (media_asset_id, language_id, audio_layout, is_audio_description) WHERE NOT is_deleted;
CREATE INDEX ix_audio_track_language ON content.audio_track (language_id);

CREATE TABLE content.subtitle_track (
    subtitle_track_id UUID                  NOT NULL DEFAULT gen_random_uuid(),
    media_asset_id    UUID                  NOT NULL,
    language_id       UUID                  NOT NULL,
    subtitle_kind     content.subtitle_kind NOT NULL,
    file_url          VARCHAR(1000)         NOT NULL,   -- WebVTT / TTML file
    is_deleted        BOOLEAN               NOT NULL DEFAULT false,
    deleted_at        TIMESTAMPTZ,
    CONSTRAINT pk_subtitle_track PRIMARY KEY (subtitle_track_id),
    CONSTRAINT fk_subtitle_track_asset    FOREIGN KEY (media_asset_id) REFERENCES content.media_asset (media_asset_id),
    CONSTRAINT fk_subtitle_track_language FOREIGN KEY (language_id)    REFERENCES ref.language (language_id),
    CONSTRAINT ck_subtitle_track_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_subtitle_track ON content.subtitle_track (media_asset_id, language_id, subtitle_kind) WHERE NOT is_deleted;
CREATE INDEX ix_subtitle_track_language ON content.subtitle_track (language_id);

-- >>>>> 04_talent.sql
-- =====================================================================
-- 04_talent.sql - people, on-screen / off-screen credits, contracts,
--                 compensation and residual payments
-- =====================================================================

CREATE TABLE talent.person (
    person_id              UUID         NOT NULL DEFAULT gen_random_uuid(),
    full_name              VARCHAR(200) NOT NULL,
    stage_name             VARCHAR(200),
    birth_date             DATE,
    nationality_country_id UUID,
    is_deleted             BOOLEAN      NOT NULL DEFAULT false,
    deleted_at             TIMESTAMPTZ,
    CONSTRAINT pk_person PRIMARY KEY (person_id),
    CONSTRAINT fk_person_country FOREIGN KEY (nationality_country_id) REFERENCES ref.country (country_id),
    CONSTRAINT ck_person_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_person_name ON talent.person (full_name);
CREATE INDEX ix_person_country ON talent.person (nationality_country_id);

CREATE TABLE talent.credit_role (
    credit_role_id  UUID         NOT NULL DEFAULT gen_random_uuid(),
    role_code       VARCHAR(30)  NOT NULL,     -- e.g. actor, director, writer, producer, composer
    role_name       VARCHAR(100) NOT NULL,
    is_on_screen    BOOLEAN      NOT NULL DEFAULT false,
    is_deleted      BOOLEAN      NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_credit_role PRIMARY KEY (credit_role_id),
    CONSTRAINT ck_credit_role_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_credit_role_code ON talent.credit_role (role_code) WHERE NOT is_deleted;

-- A credit is attached either to a whole title (movie / series / live event) or to one episode.
CREATE TABLE talent.title_credit (
    title_credit_id UUID         NOT NULL DEFAULT gen_random_uuid(),
    person_id       UUID         NOT NULL,
    credit_role_id  UUID         NOT NULL,
    title_id        UUID,
    episode_id      UUID,
    character_name  VARCHAR(200),
    billing_order   SMALLINT,
    is_deleted      BOOLEAN      NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_title_credit PRIMARY KEY (title_credit_id),
    CONSTRAINT fk_title_credit_person  FOREIGN KEY (person_id)      REFERENCES talent.person (person_id),
    CONSTRAINT fk_title_credit_role    FOREIGN KEY (credit_role_id) REFERENCES talent.credit_role (credit_role_id),
    CONSTRAINT fk_title_credit_title   FOREIGN KEY (title_id)       REFERENCES content.title (title_id),
    CONSTRAINT fk_title_credit_episode FOREIGN KEY (episode_id)     REFERENCES content.episode (episode_id),
    CONSTRAINT ck_title_credit_target CHECK (num_nonnulls(title_id, episode_id) = 1),
    CONSTRAINT ck_title_credit_billing_order CHECK (billing_order > 0),
    CONSTRAINT ck_title_credit_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_title_credit ON talent.title_credit
    (person_id, credit_role_id, COALESCE(title_id, episode_id), COALESCE(character_name, ''))
    WHERE NOT is_deleted;
CREATE INDEX ix_title_credit_role ON talent.title_credit (credit_role_id);
CREATE INDEX ix_title_credit_title ON talent.title_credit (title_id);
CREATE INDEX ix_title_credit_episode ON talent.title_credit (episode_id);

-- Contract between the platform and a person (optionally via an agency / production company partner).
CREATE TABLE talent.talent_contract (
    talent_contract_id UUID                   NOT NULL DEFAULT gen_random_uuid(),
    contract_number    VARCHAR(50)            NOT NULL,
    person_id          UUID                   NOT NULL,
    partner_id         UUID,                  -- representing agency / production company
    title_id           UUID,                  -- title the contract covers, if title-specific
    contract_status    talent.contract_status NOT NULL DEFAULT 'draft',
    signed_date        DATE,
    start_date         DATE                   NOT NULL,
    end_date           DATE,
    currency_id        UUID                   NOT NULL,
    is_deleted         BOOLEAN                NOT NULL DEFAULT false,
    deleted_at         TIMESTAMPTZ,
    CONSTRAINT pk_talent_contract PRIMARY KEY (talent_contract_id),
    CONSTRAINT fk_talent_contract_person   FOREIGN KEY (person_id)   REFERENCES talent.person (person_id),
    CONSTRAINT fk_talent_contract_partner  FOREIGN KEY (partner_id)  REFERENCES partner.partner (partner_id),
    CONSTRAINT fk_talent_contract_title    FOREIGN KEY (title_id)    REFERENCES content.title (title_id),
    CONSTRAINT fk_talent_contract_currency FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_talent_contract_range CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT ck_talent_contract_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_talent_contract_number ON talent.talent_contract (contract_number) WHERE NOT is_deleted;
CREATE INDEX ix_talent_contract_person ON talent.talent_contract (person_id);
CREATE INDEX ix_talent_contract_partner ON talent.talent_contract (partner_id);
CREATE INDEX ix_talent_contract_title ON talent.talent_contract (title_id);
CREATE INDEX ix_talent_contract_currency ON talent.talent_contract (currency_id);

CREATE TABLE talent.compensation_term (
    compensation_term_id UUID                     NOT NULL DEFAULT gen_random_uuid(),
    talent_contract_id   UUID                     NOT NULL,
    compensation_type    talent.compensation_type NOT NULL,
    amount               NUMERIC(14,2),           -- flat_fee, per_episode
    percentage           NUMERIC(5,2),            -- backend_percentage, residual_percentage
    description          VARCHAR(500),
    is_deleted           BOOLEAN                  NOT NULL DEFAULT false,
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT pk_compensation_term PRIMARY KEY (compensation_term_id),
    CONSTRAINT fk_compensation_term_contract FOREIGN KEY (talent_contract_id) REFERENCES talent.talent_contract (talent_contract_id),
    CONSTRAINT ck_compensation_term_value CHECK (
        (compensation_type IN ('flat_fee', 'per_episode') AND amount IS NOT NULL AND amount >= 0 AND percentage IS NULL)
        OR (compensation_type IN ('backend_percentage', 'residual_percentage') AND percentage IS NOT NULL AND percentage >= 0 AND percentage <= 100 AND amount IS NULL)),
    CONSTRAINT ck_compensation_term_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_compensation_term_contract ON talent.compensation_term (talent_contract_id);

CREATE TABLE talent.residual_payment (
    residual_payment_id UUID                   NOT NULL DEFAULT gen_random_uuid(),
    talent_contract_id  UUID                   NOT NULL,
    title_id            UUID                   NOT NULL,
    period_start        DATE                   NOT NULL,
    period_end          DATE                   NOT NULL,
    amount              NUMERIC(14,2)          NOT NULL,
    currency_id         UUID                   NOT NULL,
    residual_status     talent.residual_status NOT NULL DEFAULT 'pending',
    paid_at             TIMESTAMPTZ,
    is_deleted          BOOLEAN                NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_residual_payment PRIMARY KEY (residual_payment_id),
    CONSTRAINT fk_residual_payment_contract FOREIGN KEY (talent_contract_id) REFERENCES talent.talent_contract (talent_contract_id),
    CONSTRAINT fk_residual_payment_title    FOREIGN KEY (title_id)           REFERENCES content.title (title_id),
    CONSTRAINT fk_residual_payment_currency FOREIGN KEY (currency_id)        REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_residual_payment_range CHECK (period_end >= period_start),
    CONSTRAINT ck_residual_payment_amount CHECK (amount >= 0),
    CONSTRAINT ck_residual_payment_paid CHECK ((residual_status = 'paid') = (paid_at IS NOT NULL)),
    CONSTRAINT ck_residual_payment_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_residual_payment_period ON talent.residual_payment (talent_contract_id, title_id, period_start) WHERE NOT is_deleted;
CREATE INDEX ix_residual_payment_title ON talent.residual_payment (title_id);
CREATE INDEX ix_residual_payment_currency ON talent.residual_payment (currency_id);

-- >>>>> 05_rights.sql
-- =====================================================================
-- 05_rights.sql - license agreements, licensed titles, territory windows,
--                 royalty terms and royalty statements
-- =====================================================================

CREATE TABLE rights.license_agreement (
    license_agreement_id      UUID                    NOT NULL DEFAULT gen_random_uuid(),
    agreement_number          VARCHAR(50)             NOT NULL,
    partner_id                UUID                    NOT NULL,   -- licensor (studio / distributor)
    agreement_status          rights.agreement_status NOT NULL DEFAULT 'draft',
    signed_date               DATE,
    start_date                DATE                    NOT NULL,
    end_date                  DATE                    NOT NULL,
    currency_id               UUID                    NOT NULL,
    license_fee_amount        NUMERIC(14,2),                      -- fixed fee, if any
    minimum_guarantee_amount  NUMERIC(14,2),                      -- MG recouped against royalties, if any
    is_deleted                BOOLEAN                 NOT NULL DEFAULT false,
    deleted_at                TIMESTAMPTZ,
    CONSTRAINT pk_license_agreement PRIMARY KEY (license_agreement_id),
    CONSTRAINT fk_license_agreement_partner  FOREIGN KEY (partner_id)  REFERENCES partner.partner (partner_id),
    CONSTRAINT fk_license_agreement_currency FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_license_agreement_range CHECK (end_date >= start_date),
    CONSTRAINT ck_license_agreement_amounts CHECK (
        COALESCE(license_fee_amount, 0) >= 0 AND COALESCE(minimum_guarantee_amount, 0) >= 0),
    CONSTRAINT ck_license_agreement_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_license_agreement_number ON rights.license_agreement (agreement_number) WHERE NOT is_deleted;
CREATE INDEX ix_license_agreement_partner ON rights.license_agreement (partner_id);
CREATE INDEX ix_license_agreement_currency ON rights.license_agreement (currency_id);

CREATE TABLE rights.license_agreement_title (
    license_agreement_title_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    license_agreement_id       UUID        NOT NULL,
    title_id                   UUID        NOT NULL,   -- a series licenses all its seasons/episodes
    is_deleted                 BOOLEAN     NOT NULL DEFAULT false,
    deleted_at                 TIMESTAMPTZ,
    CONSTRAINT pk_license_agreement_title PRIMARY KEY (license_agreement_title_id),
    CONSTRAINT fk_license_agreement_title_agreement FOREIGN KEY (license_agreement_id) REFERENCES rights.license_agreement (license_agreement_id),
    CONSTRAINT fk_license_agreement_title_title     FOREIGN KEY (title_id)             REFERENCES content.title (title_id),
    CONSTRAINT ck_license_agreement_title_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_license_agreement_title ON rights.license_agreement_title (license_agreement_id, title_id) WHERE NOT is_deleted;
CREATE INDEX ix_license_agreement_title_title ON rights.license_agreement_title (title_id);

-- Where (territory), how (monetization model) and when (window) a licensed title may be offered.
CREATE TABLE rights.license_window (
    license_window_id          UUID                   NOT NULL DEFAULT gen_random_uuid(),
    license_agreement_title_id UUID                   NOT NULL,
    territory_id               UUID                   NOT NULL,
    monetization_model         ref.monetization_model NOT NULL,
    window_start_at            TIMESTAMPTZ            NOT NULL,
    window_end_at              TIMESTAMPTZ            NOT NULL,
    is_exclusive               BOOLEAN                NOT NULL DEFAULT false,
    is_deleted                 BOOLEAN                NOT NULL DEFAULT false,
    deleted_at                 TIMESTAMPTZ,
    CONSTRAINT pk_license_window PRIMARY KEY (license_window_id),
    CONSTRAINT fk_license_window_agreement_title FOREIGN KEY (license_agreement_title_id) REFERENCES rights.license_agreement_title (license_agreement_title_id),
    CONSTRAINT fk_license_window_territory       FOREIGN KEY (territory_id)               REFERENCES ref.territory (territory_id),
    CONSTRAINT ck_license_window_range CHECK (window_end_at > window_start_at),
    CONSTRAINT ck_license_window_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_license_window ON rights.license_window
    (license_agreement_title_id, territory_id, monetization_model, window_start_at) WHERE NOT is_deleted;
CREATE INDEX ix_license_window_territory ON rights.license_window (territory_id, monetization_model, window_start_at, window_end_at);

CREATE TABLE rights.royalty_term (
    royalty_term_id      UUID                 NOT NULL DEFAULT gen_random_uuid(),
    license_agreement_id UUID                 NOT NULL,
    royalty_basis        rights.royalty_basis NOT NULL,
    monetization_model   ref.monetization_model,           -- NULL = applies to all models
    rate_percent         NUMERIC(5,2),                     -- revenue_share
    unit_amount          NUMERIC(12,4),                    -- per_view
    fixed_amount         NUMERIC(14,2),                    -- flat_fee, minimum_guarantee
    is_deleted           BOOLEAN              NOT NULL DEFAULT false,
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT pk_royalty_term PRIMARY KEY (royalty_term_id),
    CONSTRAINT fk_royalty_term_agreement FOREIGN KEY (license_agreement_id) REFERENCES rights.license_agreement (license_agreement_id),
    CONSTRAINT ck_royalty_term_value CHECK (
        (royalty_basis = 'revenue_share' AND rate_percent IS NOT NULL AND rate_percent >= 0 AND rate_percent <= 100 AND unit_amount IS NULL AND fixed_amount IS NULL)
        OR (royalty_basis = 'per_view' AND unit_amount IS NOT NULL AND unit_amount >= 0 AND rate_percent IS NULL AND fixed_amount IS NULL)
        OR (royalty_basis IN ('flat_fee', 'minimum_guarantee') AND fixed_amount IS NOT NULL AND fixed_amount >= 0 AND rate_percent IS NULL AND unit_amount IS NULL)),
    CONSTRAINT ck_royalty_term_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_royalty_term_agreement ON rights.royalty_term (license_agreement_id);

CREATE TABLE rights.royalty_statement (
    royalty_statement_id UUID                    NOT NULL DEFAULT gen_random_uuid(),
    statement_number     VARCHAR(50)             NOT NULL,
    license_agreement_id UUID                    NOT NULL,
    period_start         DATE                    NOT NULL,
    period_end           DATE                    NOT NULL,
    statement_status     rights.statement_status NOT NULL DEFAULT 'draft',
    currency_id          UUID                    NOT NULL,
    total_royalty_amount NUMERIC(14,2)           NOT NULL DEFAULT 0,  -- frozen total of the lines once issued
    issued_date          DATE,
    paid_date            DATE,
    is_deleted           BOOLEAN                 NOT NULL DEFAULT false,
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT pk_royalty_statement PRIMARY KEY (royalty_statement_id),
    CONSTRAINT fk_royalty_statement_agreement FOREIGN KEY (license_agreement_id) REFERENCES rights.license_agreement (license_agreement_id),
    CONSTRAINT fk_royalty_statement_currency  FOREIGN KEY (currency_id)          REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_royalty_statement_range CHECK (period_end >= period_start),
    CONSTRAINT ck_royalty_statement_paid CHECK ((statement_status = 'paid') = (paid_date IS NOT NULL)),
    CONSTRAINT ck_royalty_statement_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_royalty_statement_number ON rights.royalty_statement (statement_number) WHERE NOT is_deleted;
CREATE UNIQUE INDEX uq_royalty_statement_period ON rights.royalty_statement (license_agreement_id, period_start) WHERE NOT is_deleted;
CREATE INDEX ix_royalty_statement_currency ON rights.royalty_statement (currency_id);

CREATE TABLE rights.royalty_statement_line (
    royalty_statement_line_id UUID                   NOT NULL DEFAULT gen_random_uuid(),
    royalty_statement_id      UUID                   NOT NULL,
    title_id                  UUID                   NOT NULL,
    country_id                UUID                   NOT NULL,
    monetization_model        ref.monetization_model NOT NULL,
    view_count                BIGINT                 NOT NULL DEFAULT 0,
    gross_revenue_amount      NUMERIC(14,2)          NOT NULL DEFAULT 0,
    royalty_amount            NUMERIC(14,2)          NOT NULL,
    is_deleted                BOOLEAN                NOT NULL DEFAULT false,
    deleted_at                TIMESTAMPTZ,
    CONSTRAINT pk_royalty_statement_line PRIMARY KEY (royalty_statement_line_id),
    CONSTRAINT fk_royalty_statement_line_statement FOREIGN KEY (royalty_statement_id) REFERENCES rights.royalty_statement (royalty_statement_id),
    CONSTRAINT fk_royalty_statement_line_title     FOREIGN KEY (title_id)             REFERENCES content.title (title_id),
    CONSTRAINT fk_royalty_statement_line_country   FOREIGN KEY (country_id)           REFERENCES ref.country (country_id),
    CONSTRAINT ck_royalty_statement_line_amounts CHECK (view_count >= 0 AND gross_revenue_amount >= 0 AND royalty_amount >= 0),
    CONSTRAINT ck_royalty_statement_line_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_royalty_statement_line ON rights.royalty_statement_line
    (royalty_statement_id, title_id, country_id, monetization_model) WHERE NOT is_deleted;
CREATE INDEX ix_royalty_statement_line_title ON rights.royalty_statement_line (title_id);
CREATE INDEX ix_royalty_statement_line_country ON rights.royalty_statement_line (country_id);

-- >>>>> 06_subscriber.sql
-- =====================================================================
-- 06_subscriber.sql - customer accounts, addresses, viewer profiles, devices
-- Authentication credentials are out of scope (handled by an identity provider);
-- external_auth_id links the account to that identity.
-- =====================================================================

CREATE TABLE subscriber.account (
    account_id             UUID                      NOT NULL DEFAULT gen_random_uuid(),
    external_auth_id       VARCHAR(200)              NOT NULL,   -- subject id in the identity provider
    email                  VARCHAR(320)              NOT NULL,
    phone                  VARCHAR(30),
    first_name             VARCHAR(100),
    last_name              VARCHAR(100),
    home_country_id        UUID                      NOT NULL,   -- drives catalog availability, pricing and tax
    preferred_language_id  UUID                      NOT NULL,
    account_status         subscriber.account_status NOT NULL DEFAULT 'active',
    signed_up_at           TIMESTAMPTZ               NOT NULL DEFAULT now(),
    is_deleted             BOOLEAN                   NOT NULL DEFAULT false,
    deleted_at             TIMESTAMPTZ,
    CONSTRAINT pk_account PRIMARY KEY (account_id),
    CONSTRAINT fk_account_country  FOREIGN KEY (home_country_id)       REFERENCES ref.country (country_id),
    CONSTRAINT fk_account_language FOREIGN KEY (preferred_language_id) REFERENCES ref.language (language_id),
    CONSTRAINT ck_account_email CHECK (email LIKE '%_@_%'),
    CONSTRAINT ck_account_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_account_email ON subscriber.account (lower(email)) WHERE NOT is_deleted;
CREATE UNIQUE INDEX uq_account_external_auth ON subscriber.account (external_auth_id) WHERE NOT is_deleted;
CREATE INDEX ix_account_country ON subscriber.account (home_country_id);
CREATE INDEX ix_account_language ON subscriber.account (preferred_language_id);

CREATE TABLE subscriber.account_address (
    account_address_id UUID                    NOT NULL DEFAULT gen_random_uuid(),
    account_id         UUID                    NOT NULL,
    address_type       subscriber.address_type NOT NULL,
    address_line1      VARCHAR(200)            NOT NULL,
    address_line2      VARCHAR(200),
    city               VARCHAR(100)            NOT NULL,
    region             VARCHAR(100),
    postal_code        VARCHAR(20),
    country_id         UUID                    NOT NULL,
    is_deleted         BOOLEAN                 NOT NULL DEFAULT false,
    deleted_at         TIMESTAMPTZ,
    CONSTRAINT pk_account_address PRIMARY KEY (account_address_id),
    CONSTRAINT fk_account_address_account FOREIGN KEY (account_id) REFERENCES subscriber.account (account_id),
    CONSTRAINT fk_account_address_country FOREIGN KEY (country_id) REFERENCES ref.country (country_id),
    CONSTRAINT ck_account_address_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
-- one active address per type per account
CREATE UNIQUE INDEX uq_account_address_type ON subscriber.account_address (account_id, address_type) WHERE NOT is_deleted;
CREATE INDEX ix_account_address_country ON subscriber.account_address (country_id);

CREATE TABLE subscriber.profile (
    profile_id            UUID         NOT NULL DEFAULT gen_random_uuid(),
    account_id            UUID         NOT NULL,
    profile_name          VARCHAR(50)  NOT NULL,
    is_kids               BOOLEAN      NOT NULL DEFAULT false,
    max_age_rating        SMALLINT,                 -- NULL = no restriction; compared with maturity_rating.min_age
    preferred_language_id UUID,
    avatar_code           VARCHAR(50),
    is_deleted            BOOLEAN      NOT NULL DEFAULT false,
    deleted_at            TIMESTAMPTZ,
    CONSTRAINT pk_profile PRIMARY KEY (profile_id),
    CONSTRAINT fk_profile_account  FOREIGN KEY (account_id)            REFERENCES subscriber.account (account_id),
    CONSTRAINT fk_profile_language FOREIGN KEY (preferred_language_id) REFERENCES ref.language (language_id),
    CONSTRAINT ck_profile_max_age CHECK (max_age_rating BETWEEN 0 AND 21),
    CONSTRAINT ck_profile_kids CHECK (NOT is_kids OR max_age_rating IS NOT NULL),
    CONSTRAINT ck_profile_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_profile_name ON subscriber.profile (account_id, profile_name) WHERE NOT is_deleted;
CREATE INDEX ix_profile_language ON subscriber.profile (preferred_language_id);

CREATE TABLE subscriber.device (
    device_id         UUID                   NOT NULL DEFAULT gen_random_uuid(),
    account_id        UUID                   NOT NULL,
    device_identifier VARCHAR(200)           NOT NULL,    -- app-generated install / hardware id
    device_type       subscriber.device_type NOT NULL,
    device_name       VARCHAR(100),
    os_name           VARCHAR(50),
    os_version        VARCHAR(50),
    app_version       VARCHAR(50),
    registered_at     TIMESTAMPTZ            NOT NULL DEFAULT now(),
    last_seen_at      TIMESTAMPTZ,
    is_deleted        BOOLEAN                NOT NULL DEFAULT false,   -- deregistered device
    deleted_at        TIMESTAMPTZ,
    CONSTRAINT pk_device PRIMARY KEY (device_id),
    CONSTRAINT fk_device_account FOREIGN KEY (account_id) REFERENCES subscriber.account (account_id),
    CONSTRAINT ck_device_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_device_identifier ON subscriber.device (account_id, device_identifier) WHERE NOT is_deleted;

-- >>>>> 07_billing.sql
-- =====================================================================
-- 07_billing.sql - plans & prices, tax, payment methods (tokenized),
--                  promotions, subscriptions (SVOD/AVOD), TVOD offers &
--                  purchases, invoices, payments, refunds
-- =====================================================================

-- ---------------------------------------------------------------------
-- Plans and country prices
-- ---------------------------------------------------------------------
CREATE TABLE billing.plan (
    plan_id                UUID              NOT NULL DEFAULT gen_random_uuid(),
    plan_code              VARCHAR(30)       NOT NULL,
    plan_name              VARCHAR(100)      NOT NULL,
    has_ads                BOOLEAN           NOT NULL DEFAULT false,  -- true = AVOD (ad-supported) tier
    max_concurrent_streams SMALLINT          NOT NULL,
    max_registered_devices SMALLINT          NOT NULL,
    max_video_quality      ref.video_quality NOT NULL,
    allows_downloads       BOOLEAN           NOT NULL DEFAULT false,
    is_deleted             BOOLEAN           NOT NULL DEFAULT false,
    deleted_at             TIMESTAMPTZ,
    CONSTRAINT pk_plan PRIMARY KEY (plan_id),
    CONSTRAINT ck_plan_limits CHECK (max_concurrent_streams > 0 AND max_registered_devices >= max_concurrent_streams),
    CONSTRAINT ck_plan_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_plan_code ON billing.plan (plan_code) WHERE NOT is_deleted;

CREATE TABLE billing.plan_price (
    plan_price_id   UUID                   NOT NULL DEFAULT gen_random_uuid(),
    plan_id         UUID                   NOT NULL,
    country_id      UUID                   NOT NULL,
    currency_id     UUID                   NOT NULL,
    billing_period  billing.billing_period NOT NULL,
    price_amount    NUMERIC(12,2)          NOT NULL,   -- tax-exclusive
    trial_days      SMALLINT               NOT NULL DEFAULT 0,
    effective_from  DATE                   NOT NULL,
    effective_to    DATE,                              -- NULL = open-ended
    is_deleted      BOOLEAN                NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT pk_plan_price PRIMARY KEY (plan_price_id),
    CONSTRAINT fk_plan_price_plan     FOREIGN KEY (plan_id)     REFERENCES billing.plan (plan_id),
    CONSTRAINT fk_plan_price_country  FOREIGN KEY (country_id)  REFERENCES ref.country (country_id),
    CONSTRAINT fk_plan_price_currency FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_plan_price_amount CHECK (price_amount >= 0),
    CONSTRAINT ck_plan_price_trial CHECK (trial_days >= 0),
    CONSTRAINT ck_plan_price_range CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ck_plan_price_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_plan_price ON billing.plan_price (plan_id, country_id, billing_period, effective_from) WHERE NOT is_deleted;
CREATE INDEX ix_plan_price_country ON billing.plan_price (country_id);
CREATE INDEX ix_plan_price_currency ON billing.plan_price (currency_id);

CREATE TABLE billing.tax_rate (
    tax_rate_id    UUID          NOT NULL DEFAULT gen_random_uuid(),
    country_id     UUID          NOT NULL,
    tax_name       VARCHAR(50)   NOT NULL,   -- e.g. VAT, GST, Sales Tax
    rate_percent   NUMERIC(6,3)  NOT NULL,
    effective_from DATE          NOT NULL,
    effective_to   DATE,
    is_deleted     BOOLEAN       NOT NULL DEFAULT false,
    deleted_at     TIMESTAMPTZ,
    CONSTRAINT pk_tax_rate PRIMARY KEY (tax_rate_id),
    CONSTRAINT fk_tax_rate_country FOREIGN KEY (country_id) REFERENCES ref.country (country_id),
    CONSTRAINT ck_tax_rate_percent CHECK (rate_percent BETWEEN 0 AND 100),
    CONSTRAINT ck_tax_rate_range CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ck_tax_rate_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_tax_rate ON billing.tax_rate (country_id, tax_name, effective_from) WHERE NOT is_deleted;

-- ---------------------------------------------------------------------
-- Payment methods: gateway token only, never the full card number (PCI-DSS)
-- ---------------------------------------------------------------------
CREATE TABLE billing.payment_method (
    payment_method_id   UUID                        NOT NULL DEFAULT gen_random_uuid(),
    account_id          UUID                        NOT NULL,
    method_type         billing.payment_method_type NOT NULL,
    gateway_provider    VARCHAR(50)                 NOT NULL,   -- e.g. stripe, adyen, paypal
    gateway_token       VARCHAR(255)                NOT NULL,
    card_brand          VARCHAR(30),
    card_last4          CHAR(4),
    card_expiry_month   SMALLINT,
    card_expiry_year    SMALLINT,
    is_default          BOOLEAN                     NOT NULL DEFAULT false,
    is_deleted          BOOLEAN                     NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_payment_method PRIMARY KEY (payment_method_id),
    CONSTRAINT fk_payment_method_account FOREIGN KEY (account_id) REFERENCES subscriber.account (account_id),
    CONSTRAINT ck_payment_method_card CHECK (
        method_type <> 'card'
        OR (card_brand IS NOT NULL AND card_last4 IS NOT NULL AND card_last4 ~ '^[0-9]{4}$'
            AND card_expiry_month IS NOT NULL AND card_expiry_month >= 1 AND card_expiry_month <= 12
            AND card_expiry_year IS NOT NULL AND card_expiry_year >= 2000 AND card_expiry_year <= 2100)),
    CONSTRAINT ck_payment_method_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_payment_method_token ON billing.payment_method (gateway_provider, gateway_token) WHERE NOT is_deleted;
CREATE UNIQUE INDEX uq_payment_method_default ON billing.payment_method (account_id) WHERE is_default AND NOT is_deleted;
CREATE INDEX ix_payment_method_account ON billing.payment_method (account_id);

-- ---------------------------------------------------------------------
-- Promotions and promo codes
-- ---------------------------------------------------------------------
CREATE TABLE billing.promotion (
    promotion_id            UUID                  NOT NULL DEFAULT gen_random_uuid(),
    promotion_name          VARCHAR(200)          NOT NULL,
    discount_type           billing.discount_type NOT NULL,
    discount_percent        NUMERIC(5,2),
    discount_amount         NUMERIC(12,2),
    currency_id             UUID,                  -- required for fixed_amount
    free_period_days        SMALLINT,              -- free_period
    duration_billing_cycles SMALLINT,              -- how many cycles the discount applies; NULL = once
    plan_id                 UUID,                  -- NULL = any plan
    country_id              UUID,                  -- NULL = any country
    valid_from              TIMESTAMPTZ           NOT NULL,
    valid_to                TIMESTAMPTZ,
    max_redemptions         INTEGER,               -- NULL = unlimited
    is_deleted              BOOLEAN               NOT NULL DEFAULT false,
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT pk_promotion PRIMARY KEY (promotion_id),
    CONSTRAINT fk_promotion_currency FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id),
    CONSTRAINT fk_promotion_plan     FOREIGN KEY (plan_id)     REFERENCES billing.plan (plan_id),
    CONSTRAINT fk_promotion_country  FOREIGN KEY (country_id)  REFERENCES ref.country (country_id),
    CONSTRAINT ck_promotion_value CHECK (
        (discount_type = 'percentage'   AND discount_percent IS NOT NULL AND discount_percent > 0 AND discount_percent <= 100 AND discount_amount IS NULL AND free_period_days IS NULL)
        OR (discount_type = 'fixed_amount' AND discount_amount IS NOT NULL AND discount_amount > 0 AND currency_id IS NOT NULL AND discount_percent IS NULL AND free_period_days IS NULL)
        OR (discount_type = 'free_period'  AND free_period_days IS NOT NULL AND free_period_days > 0 AND discount_percent IS NULL AND discount_amount IS NULL)),
    CONSTRAINT ck_promotion_cycles CHECK (duration_billing_cycles > 0),
    CONSTRAINT ck_promotion_range CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT ck_promotion_max CHECK (max_redemptions > 0),
    CONSTRAINT ck_promotion_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_promotion_currency ON billing.promotion (currency_id);
CREATE INDEX ix_promotion_plan ON billing.promotion (plan_id);
CREATE INDEX ix_promotion_country ON billing.promotion (country_id);

CREATE TABLE billing.promo_code (
    promo_code_id    UUID         NOT NULL DEFAULT gen_random_uuid(),
    promotion_id     UUID         NOT NULL,
    code             VARCHAR(50)  NOT NULL,
    max_uses         INTEGER,                -- NULL = limited only by the promotion
    is_deleted       BOOLEAN      NOT NULL DEFAULT false,
    deleted_at       TIMESTAMPTZ,
    CONSTRAINT pk_promo_code PRIMARY KEY (promo_code_id),
    CONSTRAINT fk_promo_code_promotion FOREIGN KEY (promotion_id) REFERENCES billing.promotion (promotion_id),
    CONSTRAINT ck_promo_code_max CHECK (max_uses > 0),
    CONSTRAINT ck_promo_code_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_promo_code ON billing.promo_code (upper(code)) WHERE NOT is_deleted;
CREATE INDEX ix_promo_code_promotion ON billing.promo_code (promotion_id);

-- ---------------------------------------------------------------------
-- Subscriptions (SVOD and AVOD tiers). A plan change closes the current
-- subscription and opens a new one, so price history is preserved.
-- ---------------------------------------------------------------------
CREATE TABLE billing.subscription (
    subscription_id         UUID                        NOT NULL DEFAULT gen_random_uuid(),
    account_id              UUID                        NOT NULL,
    plan_price_id           UUID                        NOT NULL,
    payment_method_id       UUID,
    subscription_status     billing.subscription_status NOT NULL,
    started_at              TIMESTAMPTZ                 NOT NULL,
    trial_end_at            TIMESTAMPTZ,
    current_period_start_at TIMESTAMPTZ                 NOT NULL,
    current_period_end_at   TIMESTAMPTZ                 NOT NULL,
    cancel_at_period_end    BOOLEAN                     NOT NULL DEFAULT false,
    cancelled_at            TIMESTAMPTZ,
    ended_at                TIMESTAMPTZ,
    is_deleted              BOOLEAN                     NOT NULL DEFAULT false,
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT pk_subscription PRIMARY KEY (subscription_id),
    CONSTRAINT fk_subscription_account        FOREIGN KEY (account_id)        REFERENCES subscriber.account (account_id),
    CONSTRAINT fk_subscription_plan_price     FOREIGN KEY (plan_price_id)     REFERENCES billing.plan_price (plan_price_id),
    CONSTRAINT fk_subscription_payment_method FOREIGN KEY (payment_method_id) REFERENCES billing.payment_method (payment_method_id),
    CONSTRAINT ck_subscription_period CHECK (current_period_end_at > current_period_start_at),
    CONSTRAINT ck_subscription_trial CHECK (trial_end_at IS NULL OR trial_end_at > started_at),
    CONSTRAINT ck_subscription_trialing CHECK (subscription_status <> 'trialing' OR trial_end_at IS NOT NULL),
    CONSTRAINT ck_subscription_cancelled CHECK (subscription_status <> 'cancelled' OR cancelled_at IS NOT NULL),
    CONSTRAINT ck_subscription_ended CHECK (ended_at IS NULL OR ended_at >= started_at),
    CONSTRAINT ck_subscription_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
-- one live subscription per account
CREATE UNIQUE INDEX uq_subscription_live ON billing.subscription (account_id)
    WHERE subscription_status IN ('trialing', 'active', 'past_due', 'paused') AND NOT is_deleted;
CREATE INDEX ix_subscription_account ON billing.subscription (account_id);
CREATE INDEX ix_subscription_plan_price ON billing.subscription (plan_price_id);
CREATE INDEX ix_subscription_payment_method ON billing.subscription (payment_method_id);
CREATE INDEX ix_subscription_renewal ON billing.subscription (current_period_end_at)
    WHERE subscription_status IN ('trialing', 'active', 'past_due') AND NOT is_deleted;

CREATE TABLE billing.promo_redemption (
    promo_redemption_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    promo_code_id       UUID        NOT NULL,
    account_id          UUID        NOT NULL,
    subscription_id     UUID,
    redeemed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_deleted          BOOLEAN     NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_promo_redemption PRIMARY KEY (promo_redemption_id),
    CONSTRAINT fk_promo_redemption_code         FOREIGN KEY (promo_code_id)   REFERENCES billing.promo_code (promo_code_id),
    CONSTRAINT fk_promo_redemption_account      FOREIGN KEY (account_id)      REFERENCES subscriber.account (account_id),
    CONSTRAINT fk_promo_redemption_subscription FOREIGN KEY (subscription_id) REFERENCES billing.subscription (subscription_id),
    CONSTRAINT ck_promo_redemption_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
-- an account can redeem the same code only once
CREATE UNIQUE INDEX uq_promo_redemption ON billing.promo_redemption (promo_code_id, account_id) WHERE NOT is_deleted;
CREATE INDEX ix_promo_redemption_account ON billing.promo_redemption (account_id);
CREATE INDEX ix_promo_redemption_subscription ON billing.promo_redemption (subscription_id);

-- ---------------------------------------------------------------------
-- TVOD (rent / buy individual titles)
-- ---------------------------------------------------------------------
CREATE TABLE billing.tvod_offer (
    tvod_offer_id        UUID              NOT NULL DEFAULT gen_random_uuid(),
    title_id             UUID              NOT NULL,
    country_id           UUID              NOT NULL,
    currency_id          UUID              NOT NULL,
    tvod_type            billing.tvod_type NOT NULL,
    video_quality        ref.video_quality NOT NULL,
    price_amount         NUMERIC(12,2)     NOT NULL,   -- tax-exclusive
    rental_access_hours  SMALLINT,                     -- rent: time to start watching after purchase
    rental_viewing_hours SMALLINT,                     -- rent: time to finish after first play
    valid_from           TIMESTAMPTZ       NOT NULL,
    valid_to             TIMESTAMPTZ,
    is_deleted           BOOLEAN           NOT NULL DEFAULT false,
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT pk_tvod_offer PRIMARY KEY (tvod_offer_id),
    CONSTRAINT fk_tvod_offer_title    FOREIGN KEY (title_id)    REFERENCES content.title (title_id),
    CONSTRAINT fk_tvod_offer_country  FOREIGN KEY (country_id)  REFERENCES ref.country (country_id),
    CONSTRAINT fk_tvod_offer_currency FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_tvod_offer_price CHECK (price_amount >= 0),
    CONSTRAINT ck_tvod_offer_rental CHECK (
        (tvod_type = 'rent' AND rental_access_hours IS NOT NULL AND rental_access_hours > 0
            AND rental_viewing_hours IS NOT NULL AND rental_viewing_hours > 0)
        OR (tvod_type = 'buy' AND rental_access_hours IS NULL AND rental_viewing_hours IS NULL)),
    CONSTRAINT ck_tvod_offer_range CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT ck_tvod_offer_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_tvod_offer ON billing.tvod_offer (title_id, country_id, tvod_type, video_quality, valid_from) WHERE NOT is_deleted;
CREATE INDEX ix_tvod_offer_country ON billing.tvod_offer (country_id);
CREATE INDEX ix_tvod_offer_currency ON billing.tvod_offer (currency_id);

CREATE TABLE billing.tvod_purchase (
    tvod_purchase_id    UUID          NOT NULL DEFAULT gen_random_uuid(),
    account_id          UUID          NOT NULL,
    profile_id          UUID,                       -- profile that made the purchase, if known
    tvod_offer_id       UUID          NOT NULL,
    payment_method_id   UUID          NOT NULL,
    purchased_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    price_amount        NUMERIC(12,2) NOT NULL,     -- price charged (offer price frozen at purchase)
    currency_id         UUID          NOT NULL,
    access_expires_at   TIMESTAMPTZ,                -- rent only
    first_played_at     TIMESTAMPTZ,
    viewing_expires_at  TIMESTAMPTZ,                -- rent only, set at first play
    is_deleted          BOOLEAN       NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_tvod_purchase PRIMARY KEY (tvod_purchase_id),
    CONSTRAINT fk_tvod_purchase_account        FOREIGN KEY (account_id)        REFERENCES subscriber.account (account_id),
    CONSTRAINT fk_tvod_purchase_profile        FOREIGN KEY (profile_id)        REFERENCES subscriber.profile (profile_id),
    CONSTRAINT fk_tvod_purchase_offer          FOREIGN KEY (tvod_offer_id)     REFERENCES billing.tvod_offer (tvod_offer_id),
    CONSTRAINT fk_tvod_purchase_payment_method FOREIGN KEY (payment_method_id) REFERENCES billing.payment_method (payment_method_id),
    CONSTRAINT fk_tvod_purchase_currency       FOREIGN KEY (currency_id)       REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_tvod_purchase_price CHECK (price_amount >= 0),
    CONSTRAINT ck_tvod_purchase_access CHECK (access_expires_at IS NULL OR access_expires_at > purchased_at),
    CONSTRAINT ck_tvod_purchase_viewing CHECK (viewing_expires_at IS NULL OR (first_played_at IS NOT NULL AND viewing_expires_at > first_played_at)),
    CONSTRAINT ck_tvod_purchase_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_tvod_purchase_account ON billing.tvod_purchase (account_id, purchased_at DESC);
CREATE INDEX ix_tvod_purchase_profile ON billing.tvod_purchase (profile_id);
CREATE INDEX ix_tvod_purchase_offer ON billing.tvod_purchase (tvod_offer_id);
CREATE INDEX ix_tvod_purchase_payment_method ON billing.tvod_purchase (payment_method_id);
CREATE INDEX ix_tvod_purchase_currency ON billing.tvod_purchase (currency_id);

-- ---------------------------------------------------------------------
-- Invoices, payments, refunds
-- Header totals are stored (not derived on read) because an issued invoice
-- is a legal document and must not change if rates or prices change later.
-- ---------------------------------------------------------------------
CREATE TABLE billing.invoice (
    invoice_id         UUID                   NOT NULL DEFAULT gen_random_uuid(),
    invoice_number     VARCHAR(50)            NOT NULL,
    account_id         UUID                   NOT NULL,
    billing_country_id UUID                   NOT NULL,   -- determines tax
    currency_id        UUID                   NOT NULL,
    invoice_status     billing.invoice_status NOT NULL DEFAULT 'draft',
    issue_date         DATE,
    due_date           DATE,
    subtotal_amount    NUMERIC(12,2)          NOT NULL DEFAULT 0,
    discount_amount    NUMERIC(12,2)          NOT NULL DEFAULT 0,
    tax_amount         NUMERIC(12,2)          NOT NULL DEFAULT 0,
    total_amount       NUMERIC(12,2)          NOT NULL DEFAULT 0,
    is_deleted         BOOLEAN                NOT NULL DEFAULT false,
    deleted_at         TIMESTAMPTZ,
    CONSTRAINT pk_invoice PRIMARY KEY (invoice_id),
    CONSTRAINT fk_invoice_account  FOREIGN KEY (account_id)         REFERENCES subscriber.account (account_id),
    CONSTRAINT fk_invoice_country  FOREIGN KEY (billing_country_id) REFERENCES ref.country (country_id),
    CONSTRAINT fk_invoice_currency FOREIGN KEY (currency_id)        REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_invoice_issued CHECK (invoice_status = 'draft' OR issue_date IS NOT NULL),
    CONSTRAINT ck_invoice_due CHECK (due_date IS NULL OR due_date >= issue_date),
    CONSTRAINT ck_invoice_total CHECK (total_amount = subtotal_amount - discount_amount + tax_amount),
    CONSTRAINT ck_invoice_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_invoice_number ON billing.invoice (invoice_number) WHERE NOT is_deleted;
CREATE INDEX ix_invoice_account ON billing.invoice (account_id, issue_date DESC);
CREATE INDEX ix_invoice_country ON billing.invoice (billing_country_id);
CREATE INDEX ix_invoice_currency ON billing.invoice (currency_id);
CREATE INDEX ix_invoice_open ON billing.invoice (due_date) WHERE invoice_status = 'issued' AND NOT is_deleted;

CREATE TABLE billing.invoice_line (
    invoice_line_id      UUID                      NOT NULL DEFAULT gen_random_uuid(),
    invoice_id           UUID                      NOT NULL,
    line_number          SMALLINT                  NOT NULL,
    line_type            billing.invoice_line_type NOT NULL,
    subscription_id      UUID,                     -- line_type = subscription
    tvod_purchase_id     UUID,                     -- line_type = tvod
    promo_redemption_id  UUID,                     -- line_type = discount
    description          VARCHAR(300)              NOT NULL,
    service_period_start DATE,
    service_period_end   DATE,
    quantity             NUMERIC(10,2)             NOT NULL DEFAULT 1,
    unit_amount          NUMERIC(12,2)             NOT NULL,   -- negative for discounts / credits
    tax_rate_id          UUID,
    tax_amount           NUMERIC(12,2)             NOT NULL DEFAULT 0,
    line_total_amount    NUMERIC(12,2)             NOT NULL,   -- quantity * unit_amount + tax_amount
    is_deleted           BOOLEAN                   NOT NULL DEFAULT false,
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT pk_invoice_line PRIMARY KEY (invoice_line_id),
    CONSTRAINT fk_invoice_line_invoice      FOREIGN KEY (invoice_id)          REFERENCES billing.invoice (invoice_id),
    CONSTRAINT fk_invoice_line_subscription FOREIGN KEY (subscription_id)     REFERENCES billing.subscription (subscription_id),
    CONSTRAINT fk_invoice_line_tvod         FOREIGN KEY (tvod_purchase_id)    REFERENCES billing.tvod_purchase (tvod_purchase_id),
    CONSTRAINT fk_invoice_line_promo        FOREIGN KEY (promo_redemption_id) REFERENCES billing.promo_redemption (promo_redemption_id),
    CONSTRAINT fk_invoice_line_tax_rate     FOREIGN KEY (tax_rate_id)         REFERENCES billing.tax_rate (tax_rate_id),
    CONSTRAINT ck_invoice_line_source CHECK (
        (line_type = 'subscription' AND subscription_id IS NOT NULL AND tvod_purchase_id IS NULL AND promo_redemption_id IS NULL)
        OR (line_type = 'tvod'      AND tvod_purchase_id IS NOT NULL AND subscription_id IS NULL AND promo_redemption_id IS NULL)
        OR (line_type = 'discount'  AND promo_redemption_id IS NOT NULL AND tvod_purchase_id IS NULL)
        OR (line_type = 'adjustment' AND tvod_purchase_id IS NULL AND promo_redemption_id IS NULL)),
    CONSTRAINT ck_invoice_line_period CHECK (service_period_end IS NULL OR service_period_end >= service_period_start),
    CONSTRAINT ck_invoice_line_quantity CHECK (quantity > 0),
    CONSTRAINT ck_invoice_line_total CHECK (line_total_amount = round(quantity * unit_amount, 2) + tax_amount),
    CONSTRAINT ck_invoice_line_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_invoice_line_number ON billing.invoice_line (invoice_id, line_number) WHERE NOT is_deleted;
CREATE INDEX ix_invoice_line_subscription ON billing.invoice_line (subscription_id);
CREATE INDEX ix_invoice_line_tvod ON billing.invoice_line (tvod_purchase_id);
CREATE INDEX ix_invoice_line_promo ON billing.invoice_line (promo_redemption_id);
CREATE INDEX ix_invoice_line_tax_rate ON billing.invoice_line (tax_rate_id);

CREATE TABLE billing.payment (
    payment_id              UUID                   NOT NULL DEFAULT gen_random_uuid(),
    invoice_id              UUID                   NOT NULL,
    payment_method_id       UUID                   NOT NULL,
    amount                  NUMERIC(12,2)          NOT NULL,
    currency_id             UUID                   NOT NULL,
    payment_status          billing.payment_status NOT NULL DEFAULT 'pending',
    gateway_transaction_ref VARCHAR(255),
    attempted_at            TIMESTAMPTZ            NOT NULL DEFAULT now(),
    succeeded_at            TIMESTAMPTZ,
    failure_reason          VARCHAR(500),
    is_deleted              BOOLEAN                NOT NULL DEFAULT false,
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT pk_payment PRIMARY KEY (payment_id),
    CONSTRAINT fk_payment_invoice        FOREIGN KEY (invoice_id)        REFERENCES billing.invoice (invoice_id),
    CONSTRAINT fk_payment_payment_method FOREIGN KEY (payment_method_id) REFERENCES billing.payment_method (payment_method_id),
    CONSTRAINT fk_payment_currency       FOREIGN KEY (currency_id)       REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_payment_amount CHECK (amount > 0),
    CONSTRAINT ck_payment_succeeded CHECK (
        (payment_status IN ('succeeded', 'refunded', 'partially_refunded')) = (succeeded_at IS NOT NULL)),
    CONSTRAINT ck_payment_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_payment_gateway_ref ON billing.payment (gateway_transaction_ref)
    WHERE gateway_transaction_ref IS NOT NULL AND NOT is_deleted;
CREATE INDEX ix_payment_invoice ON billing.payment (invoice_id);
CREATE INDEX ix_payment_payment_method ON billing.payment (payment_method_id);
CREATE INDEX ix_payment_currency ON billing.payment (currency_id);

CREATE TABLE billing.refund (
    refund_id           UUID                  NOT NULL DEFAULT gen_random_uuid(),
    payment_id          UUID                  NOT NULL,
    amount              NUMERIC(12,2)         NOT NULL,
    reason              VARCHAR(500),
    refund_status       billing.refund_status NOT NULL DEFAULT 'pending',
    gateway_refund_ref  VARCHAR(255),
    requested_at        TIMESTAMPTZ           NOT NULL DEFAULT now(),
    refunded_at         TIMESTAMPTZ,
    is_deleted          BOOLEAN               NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_refund PRIMARY KEY (refund_id),
    CONSTRAINT fk_refund_payment FOREIGN KEY (payment_id) REFERENCES billing.payment (payment_id),
    CONSTRAINT ck_refund_amount CHECK (amount > 0),
    CONSTRAINT ck_refund_done CHECK ((refund_status = 'succeeded') = (refunded_at IS NOT NULL)),
    CONSTRAINT ck_refund_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_refund_gateway_ref ON billing.refund (gateway_refund_ref)
    WHERE gateway_refund_ref IS NOT NULL AND NOT is_deleted;
CREATE INDEX ix_refund_payment ON billing.refund (payment_id);

-- >>>>> 08_playback.sql
-- =====================================================================
-- 08_playback.sql - viewing sessions, resume points, watchlist, ratings
-- Session-level only: no heartbeat / player events in the OLTP store.
-- =====================================================================

-- One row per play session of a media asset on a device by a profile.
-- Exactly one entitlement source: subscription (SVOD/AVOD) or TVOD purchase.
CREATE TABLE playback.viewing_session (
    viewing_session_id     UUID              NOT NULL DEFAULT gen_random_uuid(),
    profile_id             UUID              NOT NULL,
    device_id              UUID              NOT NULL,
    media_asset_id         UUID              NOT NULL,
    subscription_id        UUID,
    tvod_purchase_id       UUID,
    viewing_country_id     UUID              NOT NULL,   -- geo-resolved at session start; drives rights checks
    started_at             TIMESTAMPTZ       NOT NULL DEFAULT now(),
    ended_at               TIMESTAMPTZ,
    start_position_seconds INTEGER           NOT NULL DEFAULT 0,
    end_position_seconds   INTEGER,
    video_quality          ref.video_quality NOT NULL,
    audio_track_id         UUID,
    subtitle_track_id      UUID,
    is_deleted             BOOLEAN           NOT NULL DEFAULT false,
    deleted_at             TIMESTAMPTZ,
    CONSTRAINT pk_viewing_session PRIMARY KEY (viewing_session_id),
    CONSTRAINT fk_viewing_session_profile      FOREIGN KEY (profile_id)         REFERENCES subscriber.profile (profile_id),
    CONSTRAINT fk_viewing_session_device       FOREIGN KEY (device_id)          REFERENCES subscriber.device (device_id),
    CONSTRAINT fk_viewing_session_asset        FOREIGN KEY (media_asset_id)     REFERENCES content.media_asset (media_asset_id),
    CONSTRAINT fk_viewing_session_subscription FOREIGN KEY (subscription_id)    REFERENCES billing.subscription (subscription_id),
    CONSTRAINT fk_viewing_session_tvod         FOREIGN KEY (tvod_purchase_id)   REFERENCES billing.tvod_purchase (tvod_purchase_id),
    CONSTRAINT fk_viewing_session_country      FOREIGN KEY (viewing_country_id) REFERENCES ref.country (country_id),
    CONSTRAINT fk_viewing_session_audio        FOREIGN KEY (audio_track_id)     REFERENCES content.audio_track (audio_track_id),
    CONSTRAINT fk_viewing_session_subtitle     FOREIGN KEY (subtitle_track_id)  REFERENCES content.subtitle_track (subtitle_track_id),
    CONSTRAINT ck_viewing_session_entitlement CHECK (num_nonnulls(subscription_id, tvod_purchase_id) = 1),
    CONSTRAINT ck_viewing_session_range CHECK (ended_at IS NULL OR ended_at >= started_at),
    CONSTRAINT ck_viewing_session_positions CHECK (start_position_seconds >= 0 AND (end_position_seconds IS NULL OR end_position_seconds >= 0)),
    CONSTRAINT ck_viewing_session_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_viewing_session_profile ON playback.viewing_session (profile_id, started_at DESC);
CREATE INDEX ix_viewing_session_device ON playback.viewing_session (device_id);
CREATE INDEX ix_viewing_session_asset ON playback.viewing_session (media_asset_id);
CREATE INDEX ix_viewing_session_subscription ON playback.viewing_session (subscription_id);
CREATE INDEX ix_viewing_session_tvod ON playback.viewing_session (tvod_purchase_id);
CREATE INDEX ix_viewing_session_country ON playback.viewing_session (viewing_country_id);
CREATE INDEX ix_viewing_session_audio ON playback.viewing_session (audio_track_id);
CREATE INDEX ix_viewing_session_subtitle ON playback.viewing_session (subtitle_track_id);
-- supports the concurrent-stream limit check (open sessions)
CREATE INDEX ix_viewing_session_open ON playback.viewing_session (subscription_id) WHERE ended_at IS NULL AND NOT is_deleted;

-- Current resume point ("continue watching") per profile and asset. Updated in place.
CREATE TABLE playback.playback_progress (
    playback_progress_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    profile_id           UUID        NOT NULL,
    media_asset_id       UUID        NOT NULL,
    position_seconds     INTEGER     NOT NULL DEFAULT 0,
    is_completed         BOOLEAN     NOT NULL DEFAULT false,
    last_watched_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_deleted           BOOLEAN     NOT NULL DEFAULT false,   -- "remove from continue watching"
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT pk_playback_progress PRIMARY KEY (playback_progress_id),
    CONSTRAINT fk_playback_progress_profile FOREIGN KEY (profile_id)     REFERENCES subscriber.profile (profile_id),
    CONSTRAINT fk_playback_progress_asset   FOREIGN KEY (media_asset_id) REFERENCES content.media_asset (media_asset_id),
    CONSTRAINT ck_playback_progress_position CHECK (position_seconds >= 0),
    CONSTRAINT ck_playback_progress_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_playback_progress ON playback.playback_progress (profile_id, media_asset_id) WHERE NOT is_deleted;
CREATE INDEX ix_playback_progress_recent ON playback.playback_progress (profile_id, last_watched_at DESC)
    WHERE NOT is_completed AND NOT is_deleted;
CREATE INDEX ix_playback_progress_asset ON playback.playback_progress (media_asset_id);

CREATE TABLE playback.watchlist_item (
    watchlist_item_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    profile_id        UUID        NOT NULL,
    title_id          UUID        NOT NULL,
    added_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_deleted        BOOLEAN     NOT NULL DEFAULT false,
    deleted_at        TIMESTAMPTZ,
    CONSTRAINT pk_watchlist_item PRIMARY KEY (watchlist_item_id),
    CONSTRAINT fk_watchlist_item_profile FOREIGN KEY (profile_id) REFERENCES subscriber.profile (profile_id),
    CONSTRAINT fk_watchlist_item_title   FOREIGN KEY (title_id)   REFERENCES content.title (title_id),
    CONSTRAINT ck_watchlist_item_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_watchlist_item ON playback.watchlist_item (profile_id, title_id) WHERE NOT is_deleted;
CREATE INDEX ix_watchlist_item_title ON playback.watchlist_item (title_id);

CREATE TABLE playback.user_title_rating (
    user_title_rating_id UUID        NOT NULL DEFAULT gen_random_uuid(),
    profile_id           UUID        NOT NULL,
    title_id             UUID        NOT NULL,
    rating_value         SMALLINT    NOT NULL,     -- 1 (worst) .. 5 (best)
    rated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_deleted           BOOLEAN     NOT NULL DEFAULT false,
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT pk_user_title_rating PRIMARY KEY (user_title_rating_id),
    CONSTRAINT fk_user_title_rating_profile FOREIGN KEY (profile_id) REFERENCES subscriber.profile (profile_id),
    CONSTRAINT fk_user_title_rating_title   FOREIGN KEY (title_id)   REFERENCES content.title (title_id),
    CONSTRAINT ck_user_title_rating_value CHECK (rating_value BETWEEN 1 AND 5),
    CONSTRAINT ck_user_title_rating_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_user_title_rating ON playback.user_title_rating (profile_id, title_id) WHERE NOT is_deleted;
CREATE INDEX ix_user_title_rating_title ON playback.user_title_rating (title_id);

-- >>>>> 09_adsales.sql
-- =====================================================================
-- 09_adsales.sql - advertisers, campaigns, insertion orders, creatives,
--                  targeting, ad breaks and ad impressions (AVOD tier)
-- Agencies are partners with partner_type = 'ad_agency'.
-- =====================================================================

CREATE TABLE adsales.advertiser (
    advertiser_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    advertiser_name   VARCHAR(200) NOT NULL,
    industry          VARCHAR(100),
    country_id        UUID         NOT NULL,
    agency_partner_id UUID,                    -- default representing agency
    billing_email     VARCHAR(320),
    is_deleted        BOOLEAN      NOT NULL DEFAULT false,
    deleted_at        TIMESTAMPTZ,
    CONSTRAINT pk_advertiser PRIMARY KEY (advertiser_id),
    CONSTRAINT fk_advertiser_country FOREIGN KEY (country_id)        REFERENCES ref.country (country_id),
    CONSTRAINT fk_advertiser_agency  FOREIGN KEY (agency_partner_id) REFERENCES partner.partner (partner_id),
    CONSTRAINT ck_advertiser_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_advertiser_name ON adsales.advertiser (advertiser_name, country_id) WHERE NOT is_deleted;
CREATE INDEX ix_advertiser_country ON adsales.advertiser (country_id);
CREATE INDEX ix_advertiser_agency ON adsales.advertiser (agency_partner_id);

CREATE TABLE adsales.campaign (
    campaign_id        UUID                    NOT NULL DEFAULT gen_random_uuid(),
    advertiser_id      UUID                    NOT NULL,
    agency_partner_id  UUID,                   -- agency booking this campaign, if any
    campaign_name      VARCHAR(200)            NOT NULL,
    campaign_status    adsales.campaign_status NOT NULL DEFAULT 'draft',
    start_date         DATE                    NOT NULL,
    end_date           DATE                    NOT NULL,
    budget_amount      NUMERIC(14,2)           NOT NULL,
    currency_id        UUID                    NOT NULL,
    is_deleted         BOOLEAN                 NOT NULL DEFAULT false,
    deleted_at         TIMESTAMPTZ,
    CONSTRAINT pk_campaign PRIMARY KEY (campaign_id),
    CONSTRAINT fk_campaign_advertiser FOREIGN KEY (advertiser_id)     REFERENCES adsales.advertiser (advertiser_id),
    CONSTRAINT fk_campaign_agency     FOREIGN KEY (agency_partner_id) REFERENCES partner.partner (partner_id),
    CONSTRAINT fk_campaign_currency   FOREIGN KEY (currency_id)       REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_campaign_range CHECK (end_date >= start_date),
    CONSTRAINT ck_campaign_budget CHECK (budget_amount >= 0),
    CONSTRAINT ck_campaign_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_campaign_advertiser ON adsales.campaign (advertiser_id);
CREATE INDEX ix_campaign_agency ON adsales.campaign (agency_partner_id);
CREATE INDEX ix_campaign_currency ON adsales.campaign (currency_id);
CREATE INDEX ix_campaign_active ON adsales.campaign (start_date, end_date) WHERE campaign_status = 'active' AND NOT is_deleted;

-- The signed commercial commitment for (part of) a campaign.
CREATE TABLE adsales.insertion_order (
    insertion_order_id UUID                  NOT NULL DEFAULT gen_random_uuid(),
    io_number          VARCHAR(50)           NOT NULL,
    campaign_id        UUID                  NOT NULL,
    io_status          adsales.io_status     NOT NULL DEFAULT 'draft',
    pricing_model      adsales.pricing_model NOT NULL,
    booked_impressions BIGINT,               -- cpm / cpcv
    rate_amount        NUMERIC(12,4)         NOT NULL,   -- price per 1,000 impressions, per completed view, or flat
    total_amount       NUMERIC(14,2)         NOT NULL,
    currency_id        UUID                  NOT NULL,
    signed_date        DATE,
    flight_start_date  DATE                  NOT NULL,
    flight_end_date    DATE                  NOT NULL,
    is_deleted         BOOLEAN               NOT NULL DEFAULT false,
    deleted_at         TIMESTAMPTZ,
    CONSTRAINT pk_insertion_order PRIMARY KEY (insertion_order_id),
    CONSTRAINT fk_insertion_order_campaign FOREIGN KEY (campaign_id) REFERENCES adsales.campaign (campaign_id),
    CONSTRAINT fk_insertion_order_currency FOREIGN KEY (currency_id) REFERENCES ref.currency (currency_id),
    CONSTRAINT ck_insertion_order_range CHECK (flight_end_date >= flight_start_date),
    CONSTRAINT ck_insertion_order_amounts CHECK (rate_amount >= 0 AND total_amount >= 0),
    CONSTRAINT ck_insertion_order_impressions CHECK (pricing_model = 'flat_fee' OR (booked_impressions IS NOT NULL AND booked_impressions > 0)),
    CONSTRAINT ck_insertion_order_signed CHECK (io_status <> 'signed' OR signed_date IS NOT NULL),
    CONSTRAINT ck_insertion_order_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_insertion_order_number ON adsales.insertion_order (io_number) WHERE NOT is_deleted;
CREATE INDEX ix_insertion_order_campaign ON adsales.insertion_order (campaign_id);
CREATE INDEX ix_insertion_order_currency ON adsales.insertion_order (currency_id);

CREATE TABLE adsales.ad_creative (
    ad_creative_id   UUID                    NOT NULL DEFAULT gen_random_uuid(),
    campaign_id      UUID                    NOT NULL,
    creative_name    VARCHAR(200)            NOT NULL,
    creative_format  adsales.creative_format NOT NULL,
    duration_seconds SMALLINT,               -- video only
    asset_url        VARCHAR(1000)           NOT NULL,
    click_through_url VARCHAR(1000),
    approval_status  adsales.approval_status NOT NULL DEFAULT 'pending',
    is_deleted       BOOLEAN                 NOT NULL DEFAULT false,
    deleted_at       TIMESTAMPTZ,
    CONSTRAINT pk_ad_creative PRIMARY KEY (ad_creative_id),
    CONSTRAINT fk_ad_creative_campaign FOREIGN KEY (campaign_id) REFERENCES adsales.campaign (campaign_id),
    CONSTRAINT ck_ad_creative_duration CHECK (
        (creative_format = 'video' AND duration_seconds IS NOT NULL AND duration_seconds > 0) OR (creative_format <> 'video' AND duration_seconds IS NULL)),
    CONSTRAINT ck_ad_creative_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_ad_creative_campaign ON adsales.ad_creative (campaign_id);

-- One targeting rule per row; exactly the column matching targeting_type is filled.
CREATE TABLE adsales.campaign_targeting (
    campaign_targeting_id UUID                   NOT NULL DEFAULT gen_random_uuid(),
    campaign_id           UUID                   NOT NULL,
    targeting_type        adsales.targeting_type NOT NULL,
    is_exclusion          BOOLEAN                NOT NULL DEFAULT false,   -- true = do NOT serve here
    country_id            UUID,
    genre_id              UUID,
    title_id              UUID,
    device_type           subscriber.device_type,
    is_deleted            BOOLEAN                NOT NULL DEFAULT false,
    deleted_at            TIMESTAMPTZ,
    CONSTRAINT pk_campaign_targeting PRIMARY KEY (campaign_targeting_id),
    CONSTRAINT fk_campaign_targeting_campaign FOREIGN KEY (campaign_id) REFERENCES adsales.campaign (campaign_id),
    CONSTRAINT fk_campaign_targeting_country  FOREIGN KEY (country_id)  REFERENCES ref.country (country_id),
    CONSTRAINT fk_campaign_targeting_genre    FOREIGN KEY (genre_id)    REFERENCES content.genre (genre_id),
    CONSTRAINT fk_campaign_targeting_title    FOREIGN KEY (title_id)    REFERENCES content.title (title_id),
    CONSTRAINT ck_campaign_targeting_value CHECK (
        num_nonnulls(country_id, genre_id, title_id, device_type) = 1
        AND ((targeting_type = 'country'     AND country_id IS NOT NULL)
          OR (targeting_type = 'genre'       AND genre_id IS NOT NULL)
          OR (targeting_type = 'title'       AND title_id IS NOT NULL)
          OR (targeting_type = 'device_type' AND device_type IS NOT NULL))),
    CONSTRAINT ck_campaign_targeting_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_campaign_targeting_ref ON adsales.campaign_targeting
    (campaign_id, targeting_type, COALESCE(country_id, genre_id, title_id))
    WHERE targeting_type <> 'device_type' AND NOT is_deleted;
CREATE UNIQUE INDEX uq_campaign_targeting_device ON adsales.campaign_targeting (campaign_id, device_type)
    WHERE targeting_type = 'device_type' AND NOT is_deleted;
CREATE INDEX ix_campaign_targeting_country ON adsales.campaign_targeting (country_id);
CREATE INDEX ix_campaign_targeting_genre ON adsales.campaign_targeting (genre_id);
CREATE INDEX ix_campaign_targeting_title ON adsales.campaign_targeting (title_id);

-- An ad opportunity: a position in a VOD asset, or a scheduled break in a live EPG entry.
CREATE TABLE adsales.ad_break (
    ad_break_id           UUID                   NOT NULL DEFAULT gen_random_uuid(),
    media_asset_id        UUID,                   -- VOD: break at offset_seconds in the asset
    epg_schedule_entry_id UUID,                   -- live: break during a scheduled program
    break_position        adsales.break_position NOT NULL,
    offset_seconds        INTEGER,                -- VOD mid-roll offset; live: offset from program start
    max_duration_seconds  SMALLINT               NOT NULL,
    max_ads               SMALLINT               NOT NULL DEFAULT 1,
    is_deleted            BOOLEAN                NOT NULL DEFAULT false,
    deleted_at            TIMESTAMPTZ,
    CONSTRAINT pk_ad_break PRIMARY KEY (ad_break_id),
    CONSTRAINT fk_ad_break_asset FOREIGN KEY (media_asset_id)        REFERENCES content.media_asset (media_asset_id),
    CONSTRAINT fk_ad_break_epg   FOREIGN KEY (epg_schedule_entry_id) REFERENCES content.epg_schedule_entry (epg_schedule_entry_id),
    CONSTRAINT ck_ad_break_owner CHECK (num_nonnulls(media_asset_id, epg_schedule_entry_id) = 1),
    CONSTRAINT ck_ad_break_offset CHECK (
        (break_position = 'mid_roll' AND offset_seconds IS NOT NULL AND offset_seconds > 0) OR (break_position <> 'mid_roll' AND offset_seconds IS NULL)),
    CONSTRAINT ck_ad_break_limits CHECK (max_duration_seconds > 0 AND max_ads > 0),
    CONSTRAINT ck_ad_break_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE UNIQUE INDEX uq_ad_break_asset ON adsales.ad_break (media_asset_id, break_position, COALESCE(offset_seconds, 0))
    WHERE media_asset_id IS NOT NULL AND NOT is_deleted;
CREATE UNIQUE INDEX uq_ad_break_epg ON adsales.ad_break (epg_schedule_entry_id, break_position, COALESCE(offset_seconds, 0))
    WHERE epg_schedule_entry_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX ix_ad_break_asset ON adsales.ad_break (media_asset_id);
CREATE INDEX ix_ad_break_epg ON adsales.ad_break (epg_schedule_entry_id);

-- One served ad. High volume: candidate for monthly range partitioning on served_at (see physical model).
CREATE TABLE adsales.ad_impression (
    ad_impression_id    UUID        NOT NULL DEFAULT gen_random_uuid(),
    ad_break_id         UUID        NOT NULL,
    ad_creative_id      UUID        NOT NULL,
    insertion_order_id  UUID        NOT NULL,
    viewing_session_id  UUID        NOT NULL,
    served_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    pod_position        SMALLINT    NOT NULL DEFAULT 1,   -- order of the ad within the break
    watched_seconds     SMALLINT    NOT NULL DEFAULT 0,
    is_completed        BOOLEAN     NOT NULL DEFAULT false,
    is_clicked          BOOLEAN     NOT NULL DEFAULT false,
    is_deleted          BOOLEAN     NOT NULL DEFAULT false,
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT pk_ad_impression PRIMARY KEY (ad_impression_id),
    CONSTRAINT fk_ad_impression_break    FOREIGN KEY (ad_break_id)        REFERENCES adsales.ad_break (ad_break_id),
    CONSTRAINT fk_ad_impression_creative FOREIGN KEY (ad_creative_id)     REFERENCES adsales.ad_creative (ad_creative_id),
    CONSTRAINT fk_ad_impression_io       FOREIGN KEY (insertion_order_id) REFERENCES adsales.insertion_order (insertion_order_id),
    CONSTRAINT fk_ad_impression_session  FOREIGN KEY (viewing_session_id) REFERENCES playback.viewing_session (viewing_session_id),
    CONSTRAINT ck_ad_impression_values CHECK (pod_position > 0 AND watched_seconds >= 0),
    CONSTRAINT ck_ad_impression_soft_delete CHECK (is_deleted = (deleted_at IS NOT NULL))
);
CREATE INDEX ix_ad_impression_break ON adsales.ad_impression (ad_break_id);
CREATE INDEX ix_ad_impression_creative ON adsales.ad_impression (ad_creative_id);
CREATE INDEX ix_ad_impression_io ON adsales.ad_impression (insertion_order_id, served_at);
CREATE INDEX ix_ad_impression_session ON adsales.ad_impression (viewing_session_id);

COMMIT;
