# TP3 — Scénario de test

Neuf cas. Pour chacun : ce que vous faites, ce qui doit se produire, et ce que vous avez obtenu.
Les cas marqués **doit échouer** sont réussis quand ils échouent : notez le message exact.

| # | Ce que je fais | Attendu | Obtenu |
|---|---|---|---|
| T1 | `CALL p_emprunter(<code d'un exemplaire disponible>, <adhérent actif sans emprunt>, @id);` | un emprunt créé, `@id` renseigné, exemplaire indisponible, une ligne dans `journal_action` | Non exécuté : serveur MySQL et base TP2 absents du dossier |
| T2 | `CALL p_emprunter(<le même code-barres>, <un autre adhérent>, @id);` — **doit échouer** | exemplaire déjà emprunté | Non exécuté ; erreur attendue : `Exemplaire déjà emprunté ou indisponible.` |
| T3 | `CALL p_emprunter(<un code disponible>, <adhérent avec actif = 0>, @id);` — **doit échouer** | inscription inactive | Non exécuté ; erreur attendue : `Inscription inactive : l'adhérent ne peut pas emprunter.` |
| T4 | `CALL p_emprunter('MED-99999', 1, @id);` — **doit échouer** | code-barres inconnu | Non exécuté ; erreur attendue : `Code-barres inconnu.` |
| T5 | Cinq emprunts pour le même adhérent, puis un sixième — **doit échouer** | quota de 5 atteint | Non exécuté ; erreur attendue : `Quota atteint : cinq emprunts en cours maximum.` |
| T6 | `CALL p_emprunter(<un code disponible>, <adhérent devant plus de 10 €>, @id);` — **doit échouer** | pénalités impayées | Non exécuté ; erreur attendue : `Emprunt refusé : plus de 10,00 € de pénalités impayées.` |
| T7 | `INSERT INTO emprunt (exemplaire_id, adherent_id, date_emprunt, date_retour_prevue) VALUES (<libre>, 2, NULL, NULL);` | la ligne existe, `date_emprunt` = aujourd'hui, retour prévu à +14 jours, exemplaire indisponible | Non exécuté ; résultat attendu : valeurs définies par le trigger `BEFORE INSERT`, exemplaire indisponible |
| T8 | `CALL p_rendre(<code d'un emprunt en retard>);` | emprunt clos, exemplaire disponible, pénalité créée au bon montant | Non exécuté ; montant attendu : 0,20 € × nombre de jours de retard |
| T9 | `CALL p_rendre(<le même code>);` — **doit échouer** | aucun emprunt en cours | Non exécuté ; erreur attendue : `Aucun emprunt en cours pour cet exemplaire.` |

## Les requêtes qui trouvent les cas de test

Plutôt que de coder en dur des identifiants qui changeront, laissez la base les choisir :

```sql
-- un exemplaire disponible
SET @code = (SELECT code_barre FROM exemplaire
              WHERE disponible = 1 AND etat <> 'hors_service' ORDER BY id LIMIT 1);

-- un adhérent actif, sans emprunt et sans pénalité
SET @adherent = (SELECT a.id FROM adherent a
                  WHERE a.actif = 1
                    AND f_nb_emprunts_en_cours(a.id) = 0
                    AND f_penalites_dues(a.id) = 0
                  ORDER BY a.id LIMIT 1);

-- un adhérent qui doit plus de 10 €
SET @mauvais_payeur = (SELECT adherent_id FROM penalite
                        WHERE payee = 0 GROUP BY adherent_id
                       HAVING SUM(montant) > 10 LIMIT 1);

-- un emprunt en retard
SET @code_retard = (SELECT ex.code_barre
                      FROM emprunt em JOIN exemplaire ex ON ex.id = em.exemplaire_id
                     WHERE em.date_retour_reelle IS NULL
                       AND em.date_retour_prevue < CURDATE()
                     ORDER BY em.date_retour_prevue LIMIT 1);
```

## Les vérifications après chaque test

```sql
-- l'exemplaire a-t-il changé d'état ?
SELECT code_barre, disponible FROM exemplaire WHERE code_barre = @code;

-- la trace existe-t-elle ?
SELECT operation, cle, auteur, details FROM journal_action ORDER BY id DESC LIMIT 3;

-- la pénalité est-elle au bon montant ?
SELECT adherent_id, montant, motif FROM penalite ORDER BY id DESC LIMIT 1;
```

## Conclusion

Deux questions, deux réponses en une phrase chacune :

**1.** Le test T7 passe par un `INSERT` direct, sans procédure. Qu'est-ce qui, malgré tout, reste garanti — et qu'est-ce qui ne l'est plus ?

> L'INSERT direct conserve les garanties portées par les triggers : dates cohérentes, disponibilité synchronisée et traçabilité. En revanche, les règles métier propres à `p_emprunter` (adhérent actif, quota et pénalités) ne sont plus contrôlées.

**2.** Une règle du tableau du sujet pourrait changer de camp (passer de la procédure au trigger, ou l'inverse). Laquelle, et qu'est-ce que cela changerait ?

> Le délai de prêt de 14 jours pourrait être déplacé du trigger vers la procédure : seuls les prêts créés par cette procédure auraient alors ce délai, tandis qu'un INSERT direct pourrait l'omettre.
