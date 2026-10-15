USE mediatheque;

CREATE TABLE IF NOT EXISTS journal_action (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  table_cible VARCHAR(40)     NOT NULL,
  operation   VARCHAR(10)     NOT NULL,
  cle         VARCHAR(40)     NOT NULL,
  auteur      VARCHAR(100)    NOT NULL,
  horodatage  DATETIME        NOT NULL,
  details     VARCHAR(255)        NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_emprunt_before_insert;
DROP TRIGGER IF EXISTS trg_emprunt_after_insert;
DROP TRIGGER IF EXISTS trg_emprunt_after_update;

DELIMITER //

CREATE TRIGGER trg_emprunt_before_insert
BEFORE INSERT ON emprunt
FOR EACH ROW
BEGIN
  SET NEW.date_emprunt = COALESCE(NEW.date_emprunt, CURDATE());
  SET NEW.date_retour_prevue = COALESCE(
    NEW.date_retour_prevue,
    DATE_ADD(NEW.date_emprunt, INTERVAL 14 DAY)
  );

  IF NEW.date_retour_prevue < NEW.date_emprunt THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La date de retour prévue ne peut pas précéder la date d''emprunt.';
  END IF;
END//

CREATE TRIGGER trg_emprunt_after_insert
AFTER INSERT ON emprunt
FOR EACH ROW
BEGIN
  UPDATE exemplaire
     SET disponible = 0
   WHERE id = NEW.exemplaire_id;

  INSERT INTO journal_action (
    table_cible, operation, cle, auteur, horodatage, details
  )
  VALUES (
    'emprunt',
    'INSERT',
    CAST(NEW.id AS CHAR),
    SESSION_USER(),
    NOW(),
    CONCAT('Création de l''emprunt pour l''adhérent ', NEW.adherent_id)
  );
END//

CREATE TRIGGER trg_emprunt_after_update
AFTER UPDATE ON emprunt
FOR EACH ROW
BEGIN
  IF OLD.date_retour_reelle IS NULL
     AND NEW.date_retour_reelle IS NOT NULL THEN
    UPDATE exemplaire
       SET disponible = 1
     WHERE id = NEW.exemplaire_id;
  END IF;

  INSERT INTO journal_action (
    table_cible, operation, cle, auteur, horodatage, details
  )
  VALUES (
    'emprunt',
    'UPDATE',
    CAST(NEW.id AS CHAR),
    SESSION_USER(),
    NOW(),
    IF(
      OLD.date_retour_reelle IS NULL
        AND NEW.date_retour_reelle IS NOT NULL,
      'Retour enregistré, exemplaire rendu disponible',
      'Mise à jour de l''emprunt'
    )
  );
END//

DELIMITER ;
