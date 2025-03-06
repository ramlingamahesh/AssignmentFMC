

## Web Application Tech stack
- React
- Nodejs
- MySQL

## Frontend Installation
__NOTE__: Install Nodejs and nginx on your System

1. Install dependency to run react application
    ```
    cd application-code/web-tier
    npm install
    ```
2. Make Changes in nginx.conf file for backend application
    ```
    cd ..
    vi nginx.conf
    ```
    ```
    #proxy for internal lb
    location /api/{
        proxy_pass http://[REPLACE-WITH-INTERNAL-LB-DNS]:80/;
    }
    ```
3. Now let's Create Build Folder
    ```
    npm run build
    ```
Now move content of build/* to Nginx root location /var/www/html. Now start your nginx server with ```sudo systemctl start nginx```, review you webpage on :80.


## Backend Installation
__NOTE__ : Install Nodejs and mysql on your System
1. Install dependency to run Nodejs API
    ```
    cd application-code/app-tier
    npm install
    ```
2. Make Changes in DbConfig.js file
    ```
    vi application-code/app-tier/DbConfig.js
    ```
    ```
    module.exports = Object.freeze({
    DB_HOST : '<Enter hostname>',
    DB_USER : '<Enter Admin user>',
    DB_PWD : '<Enter Admin Passwd>',
    DB_DATABASE : 'webappdb'
    });
    ```
3. Create `webappdb` database and create `Transactions` table on MySQL server 

    ```
    mysql -h <Database Hostname> -u <Admin User> -p<Admin Passwd> < db_setup.sql
    ```
4. Run you Application
    ```
    npm install -g pm2

    pm2 start index.js
    startup_as_process=$(pm2 startup | grep -o 'sudo env.*')
    eval "$startup_as_process"
    pm2 save
    ```

Above Command will start Node Server on :4000. You can can health of your server by running 
- ```curl http://localhost:4000/health``` for application health
- ```curl http://localhost:4000/transaction``` for database health

Now  application is ready !!

