require "/home/savio/www/criceta/backup.rb"

ftps = []
ftps << {host: "host", user: "user", password: "password"}

databases = []
databases << {type: "mysql", host: "localhost", user: "username", password: "password", name: "name"}
databases << {type: "postgresql", host: "localhost", user: "username", password: "password", name: "name"}


folders = []
folders << '/home/savio/www/agape'

folder = Time.new.strftime(Time.new.strftime('%Y-%m-%d_%H-%M-%S'))
params = { 
	backup: {
		to_folder: false,
		folder: folder,
		ftp: ftps,
		objects: { folders: folders, databases: databases },
		rotates:["/mnt/backup2/projects/billing2"],
		},

		server: {
			os: 'linux',
			key: true,
			ssh_host: "localhost",
			ssh_user: "savio",
			ssh_password: "",
			tmp_dir: "/tmp/#{folder}"
		},
	} 	

	backup = Backup.new(params)
	#backup.set(params)
	puts backup.exec
