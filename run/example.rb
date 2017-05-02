require "/home/savio/www/criceta/backup.rb"

ftps = []
ftps << {host: "backup.host", user: "test1", password: "1test"}

databases = []
#databases << {type: "mysql", host: "localhost", user: "user", password: "password", name: "dbname"}

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
		commands: {
			'linux' => {'ncftpput' => '/usr/bin/ncftpput'},
			'freebsd' => {'ncftpput' => '/usr/local/bin/ncftpput'},
		}
		
	} 	

	backup = Backup.new(params)
	#backup.set(params)
	puts backup.exec
