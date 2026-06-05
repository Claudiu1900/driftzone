# driftzone_clothes

Admin-only clothes editor for FiveM.

Access:
- /haine or /clothes: admin_level 7+ and aduty yes only
- /fixskin id: admin_level 7+ and aduty yes only
- /setcl id category drawable: admin_level 7+ and aduty yes only
- /bancl category drawable: admin_level 7+ and aduty yes only

Categories:
1 hair
2 hat
3 mask
4 glasses
5 jacket
6 torso
7 top
8 insignia
9 pants
10 shoes

Database:
- users.clothes in database driftzone
- unallowed_clothes and clothes_logs in database driftzone_logs

If your MySQL does not support ADD COLUMN IF NOT EXISTS, manually add:
ALTER TABLE users ADD COLUMN clothes LONGTEXT NULL;


Categorii comenzi:
1 hair
2 hat
3 mask
4 glasses
5 jacket
6 torso
7 top
8 insignia
9 pants
10 shoes
11 bag/geanta

Update: categoria bag/geanta foloseste component ID 5 si se salveaza in users.clothes cu cheia bag.
