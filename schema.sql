CREATE TABLE packages (
    id          INTEGER PRIMARY KEY AUTOINCREMENT
                        NOT NULL,
    name        TEXT    NOT NULL,
    description TEXT,
    license     TEXT    NOT NULL,
    web         TEXT    NOT NULL,
    maintainer  TEXT    NOT NULL
);

CREATE TABLE releases (
    id      INTEGER PRIMARY KEY AUTOINCREMENT
                    NOT NULL,
    pkg_id  INTEGER NOT NULL,
    version TEXT    NOT NULL,
    method  TEXT    NOT NULL,
    uri     TEXT    NOT NULL,
    FOREIGN KEY ( pkg_id )
        REFERENCES packages ( id )
        ON DELETE CASCADE
);

CREATE TABLE tags (
    pkg_id INTEGER
                   NOT NULL,
    value  TEXT    NOT NULL,
    FOREIGN KEY ( pkg_id )
        REFERENCES packages ( id )
        ON DELETE CASCADE
);

CREATE TABLE licenses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT
                            NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     TEXT
);