require "/home/savio/scripts/backup.rb"

folder = Time.new.strftime(Time.new.strftime('%Y-%m-%d_%H-%M-%S'))
params = { 
	backup: {
		to_folder: false,
		folder: folder,
		ftps: [{
			host: "host",
			user: "login",
			password: "password"
			}
			],

			objects: {
				folders: [
					"/usr/local/billing2_vpn",
					"/usr/local/www/billing2a",
					"/var/cron",
					"/etc/crontab"
					],
					databases: [
						{type: "mysql",
							host: "localhost",
							user: "user",
							password: "password",
							name: "dbname"
							}
							]
						},
						rotates:["/mnt/backup2/projects/billing2"]
						},

						server: {
							ssh_host: "host",
							ssh_user: "user",
							ssh_password: "password",
							tmp_dir: "/tmp/#{folder}"

						}

					} 	



					backup = Backup.new
					backup.set(params)
					puts backup.exec
