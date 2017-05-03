class Backup
  require 'rubygems'
  require 'net/ssh'
  require 'date'
  require 'colorize'
  require 'colorized_string'

  def initialize params
    set params
  end

  def set params
    commands = {
      'linux'   => {ncftpput: '/usr/bin/ncftpput',        mysqldump: '/usr/bin/mysqldump', pg_dump: '/usr/bin/pg_dump'},
      'freebsd' => {ncftpput: '/usr/local/bin/ncftpput',  mysqldump: '/usr/local/bin/mysqldump', pg_dump: '/usr/local/bin/pg_dump'}
    }

    @params = params
    @params[:commands]=commands[@params[:server][:os]]

  end


  def exec
    #step 1) create tmp dir
    exec_ssh "mkdir #{@params[:server][:tmp_dir]}" if @params[:server][:tmp_dir]

    #step 2) backup folders
    @params[:backup][:objects][:folders].each do |folder|
      backup_folder folder
    end

    #step 3) backup database 
    @params[:backup][:objects][:databases].each do |db|
      backup_db db
    end

    #step 4) remove tmp dir
    exec_ssh "rm -r #{@params[:server][:tmp_dir]}"

    #step 5) Execute rotate backups
    rotate_backups
  end

  def exec2
    unless @params[:backup][:rotates].nil?
      @params[:backup][:rotates].each do |rotate_path|
        rotate rotate_path
      end
    end
  end

  def backup_folder folder
    if @params[:backup][:to_folder]
      file = "#{@params[:server][:tmp_dir]}/#{get_folder_name(folder)}.tar.gz"
      cmd = "sudo -s tar czvf #{file} #{folder}"
      exec_ssh cmd  
      file_upload_to_ftp @params[:backup][:folder], file
    else
      file = "#{get_folder_name(folder)}.tar.gz"
      @params[:backup][:ftp].each do |ftp|
        create_backup_folder ftp
        cmd = "sudo -s tar -czvf - #{folder} | ncftpput -u #{ftp[:user]} -p #{ftp[:password]} -c #{ftp[:host]} #{@params[:backup][:folder]}/#{file}"
        exec_ssh cmd
      end
    end
  end

  def backup_db db
    backup_mysql db if db[:type] == 'mysql'
    backup_postgres db if db[:type] == 'postgresql'
  end


  def backup_mysql db
    if db[:type] == 'mysql'
      if @params[:backup][:to_folder]
        file = "#{@params[:server][:tmp_dir]}/dump_#{db[:name]}.sql.gz"
        cmd = "sudo -s #{@params[:commands][:mysqldump]} -u #{db[:user]} -p#{db[:password]} -f --default-character-set=utf8 --databases #{db[:name]} -i --hex-blob --quick  | gzip -c > #{file}"
        file_upload_to_ftp @params[:backup][:folder], file
        exec_ssh cmd    
      else
        file = "dump_#{db[:name]}.sql.gz"
        @params[:backup][:ftp].each do |ftp|
          create_backup_folder ftp
          cmd = "sudo -s #{@params[:commands][:mysqldump]} --user=#{db[:user]} --password=#{db[:password]} -f --default-character-set=utf8 --databases #{db[:name]} -i --hex-blob --quick  | gzip -9 | ncftpput -u #{ftp[:user]} -p #{ftp[:password]} -c #{ftp[:host]} #{@params[:backup][:folder]}/#{file}"    
          exec_ssh cmd    
        end
      end
    end
  end

  def backup_postgres db
    if db[:type] == 'postgresql'
      if @params[:backup][:to_folder]
        file = "#{@params[:server][:tmp_dir]}/dump_#{db[:name]}.sql.gz"
        cmd = "#{@params[:commands][:pg_dump]} postgresql://#{db[:user]}:#{db[:password]}@#{db[:host]}:5432/#{db[:name]} | gzip -c > #{file}"
        file_upload_to_ftp @params[:backup][:folder], file
        exec_ssh cmd    
      else
        file = "dump_postgres_#{db[:name]}.sql.gz"
        @params[:backup][:ftp].each do |ftp|
          create_backup_folder ftp
          cmd = "#{@params[:commands][:pg_dump]} postgresql://#{db[:user]}:#{db[:password]}@127.0.0.1:5432/#{db[:name]} | gzip -9 | ncftpput -u #{ftp[:user]} -p #{ftp[:password]} -c #{ftp[:host]} #{@params[:backup][:folder]}/#{file}"    
          exec_ssh cmd    
        end
      end
    end
  end



  def file_upload_to_ftp to_folder, file
    @params[:backup][:ftp].each do |ftp|
      create_backup_folder ftp
      cmd = "/usr/local/bin/lftp -u #{ftp[:user]},\"#{ftp[:password]}\" -e \"mkdir #{to_folder}; mput -O /#{to_folder}/ #{file};exit\" #{ftp[:host]}"
      exec_ssh cmd
      cmd = "rm #{file}"
      exec_ssh cmd
    end
  end

  def rotate path, periods = nil
    default_periods= 
    [
    {start:96422400, stop:9642240000000, count:0}, # 
    {start:64281601, stop:96422400, count:1}, # рік 3
    {start:32140801, stop:64281600, count:1}, # рік 2
    {start:29462401, stop:32140800, count:1}, # місяць 12
    {start:26784001, stop:29462400, count:1}, # місяць 11
    {start:24105601, stop:26784000, count:1}, # місяць 10
    {start:21427201, stop:24105600, count:1}, # місяць 9
    {start:18748801, stop:21427200, count:1}, # місяць 8
    {start:16070401, stop:18748800, count:1}, # місяць 7
    {start:13392001, stop:16070400, count:1}, # місяць 6
    {start:10713601, stop:13392000, count:1}, # місяць 5
    {start:8035201, stop:10713600, count:1}, # місяць 4
    {start:5356801, stop:8035200, count:1}, # місяць 3
    {start:2678401, stop:5356800, count:1}, # місяць 2
    {start:1814401, stop:2678400, count:1}, # четвертий тиждень
    {start:1209601, stop:1814400, count:1}, # третій тиждень
    {start:604801, stop:1209600, count:1}, # другий тиждень
    {start:172801, stop:604800, count:5}, # 2..7 днів
    {start:0, stop:172800, count:12}] # 1..2 днів


    periods ||= default_periods

    periods.each do |period|
      puts "period: #{period}"
      puts "- path:#{path}"
      objects = get_objects path, period
      puts "objects:#{objects}"
      remove_objects objects, path, period
      puts objects
      puts "_____________________________________"
    end
  end

  def test path
  #date = Date.strptime(date, '%Y-%m-%d')
  (1..9600).each do |minute|
    folder=(Time.new(2016, 8, 20 , 13, 30, 1)-(minute*3600)).strftime("%Y-%m-%d_%H-%M-%S")
    cmd = "mkdir #{path}/#{folder}"
      #puts cmd
      system(cmd)
    end

  end




  private

  def get_folder_name name
    name.gsub '/', '_'
  end

  # повертає hash об'єктів (директорій або файлів) в path, які належать до періоду period, де
  # key - к-ть секунд від дати now_date
  # value - назва об'єкту(файла або папки)
  # p.s Дата береться з назви файлу, формат: YYYY-MM-DD HH:II:SS
  # TODO - зробити вибір джерела дати (з назви файлу/дату створення файлу)
  def get_objects path, period, now_time=Time.new
    res={}
    
    puts "objects: #{Dir.entries(path)}"
    Dir.entries(path).each do |object|
      unless object=='.' or object == '..'
        puts "object: #{object}"

        year =object[0..3] 
        month = object[5..6]
        day = object[8..9]
        hour = object[11..12]
        minute = object[14..15]
        second = object[17..18]
        puts "Time.new(#{year}, #{month}, #{day}, #{hour}, #{minute}, #{second})"
        unless year.nil? or month.nil? or day.nil? or hour.nil? or minute.nil? or second.nil?
          object_time = Time.new(year, month, day, hour, minute, second)

          seconds=(now_time.-object_time).to_i
          puts "seconds:#{seconds}"
          res[seconds] = object if (period[:start].to_i..period[:stop].to_i).include?(seconds)
          puts "res:#{res}"
          puts "period_start: #{period[:start]}"
          puts "period_stop: #{period[:stop]}"
        end
      end
    end
    Hash[res.sort]
    res
  end

  # Залишити period[:count] об'єктів, усі інші знищити, починаючи з перших
  def remove_objects objects, path, period
    objects=objects.values.reverse
    objects_count = objects.count
    
    if objects_count > period[:count]
      puts "****------BEGIN----------"
      puts "objects: #{objects}"
      puts "path:#{path}"
      puts "period: #{period}"
      puts "objects_count:#{objects_count}"

      remove_count = objects_count - period[:count]  
      puts "remove_count:#{remove_count}"

      (0..remove_count-1).each do |i| 
        puts "*) --------"
        puts "*) index: #{i}"
        puts "*) ===> remove_object: #{objects[i]}"
        puts "*) --------"
        remove_object(objects[i], path) 
      end

      puts "****------END----------"
    else
      puts "No deleted"
      puts "objects_count:#{objects_count}"
      puts "period: #{period}"
    end
  end

  def remove_object object, path
    cmd = "rm -r #{path}/#{object}"
    puts cmd
    system(cmd)

  end

  def set_params params
    #set_params = params.permit(:title )
  end

  def rotate_backups
    unless @params[:backup][:rotates].nil?
      @params[:backup][:rotates].each do |rotate_path|
        rotate rotate_path
      end
    end
  end

  def log str, color=''
    color = "black" if color.empty?
    puts str
  end

  def exec_ssh cmd
    log "ssh(cmd): #{cmd}","green"
    if @params[:server][:keys] == false
      begin
        ssh = Net::SSH.start(@params[:server][:ssh_host], @params[:server][:ssh_user], password: @params[:server][:ssh_password])
      rescue
        puts "Unable to connect to #{@params[:server][:ssh_host]} using #{@params[:server][:ssh_user]}/#{@params[:server][:ssh_password]}"
      end
    else
      begin
        ssh = Net::SSH.start(@params[:server][:ssh_host],@params[:server][:ssh_user])
      rescue
        puts "Unable to connect to #{@params[:server][:ssh_host]} using #{@params[:server][:ssh_user]}/#{@params[:server][:ssh_password]}"
      end
    end  
    res = ssh.exec!(cmd)
    ssh.close
    log "ssh(rezult): #{res}"
  end


  def create_backup_folder ftp
    cmd = "ncftp ftp://#{ftp[:user]}:#{ftp[:password]}@#{ftp[:host]}/<<EOF
    mkdir #{@params[:backup][:folder]}
    EOF
    "
    exec_ssh cmd
  end

end