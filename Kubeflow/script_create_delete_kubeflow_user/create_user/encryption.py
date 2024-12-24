#make password

import bcrypt
import sys

password = sys.argv[1]

salt = bcrypt.gensalt()
hashed_password = bcrypt.hashpw(password.encode('utf-8'), salt)


hashed_password = hashed_password.decode('utf-8')
print(hashed_password)
