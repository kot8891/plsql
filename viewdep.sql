create or replace procedure ViewDep
    (
        p_city LOCATIONS.city%TYPE
    )
is
    vFile utl_file.file_type;
    bFlag boolean:=false;
    -- here is the main select statement with all joins 
    cursor qDeps is
        select  dep.DEPARTMENT_NAME as dep
            ,   cont.COUNTRY_NAME   as country
            ,   loc.CITY            as city
            ,   loc.STREET_ADDRESS  as address
        from    DEPARTMENTS dep 
            join    LOCATIONS loc
                on dep.LOCATION_ID = loc.LOCATION_ID
            join COUNTRIES cont
                on loc.COUNTRY_ID = cont.COUNTRY_ID
         where loc.city = p_city;
begin
    vFile := sys.utl_file.fopen
        (
            location => 'TMP'
        ,   filename => 'tmp.csv'
        ,   OPEN_MODE => 'W'
        );
    sys.UTL_FILE.put_line(vFile, 'In the city '||p_city||' those departments 
    are located:');
    -- here is writing rows into the file
    for deps in qDeps
    loop
        sys.utl_file.PUT_LINE(vFile, deps.dep); 
        DBMS_output.put_line(deps.dep);
        if not bFlag then
            bFlag:=true;
        end if;
    end loop;
    if not bFlag then
        sys.utl_file.PUT_LINE(vFile, 'Departments not found in the city '||p_city);
        dbms_output.put_line('Departments not found in the city '||p_city);
    end if;
    sys.utl_file.FCLOSE(vFile);

    -- here is creating credentials, which is used to run shell script to 
    -- transport file to another server
    begin
        dbms_output.put_line('start making credentials');
        dbms_scheduler.create_credential
          (
            credential_name => 'user1_cred',
            username        => 'root',
            password        => 'root_pass'
          );
    exception 
        when others then
            dbms_output.put_line('Possibly credential already exists');
    end;

    -- Here is a job to push csv to another server
    dbms_scheduler.create_job
      (
       job_name             =>'copy_csv',
       job_action           =>'/tmp/copy_csv.sh',
       job_type             =>'EXECUTABLE',
       number_of_arguments  =>0,
       enabled              =>FALSE,
       auto_drop            => TRUE,
       credential_name      => 'user1_cred'
      );

    DBMS_SCHEDULER.enable('copy_csv');

    dbms_output.PUT_LINE('run_job is starting...');

    DBMS_SCHEDULER.run_job (job_name=> 'copy_csv');

    dbms_output.PUT_LINE('run_job finished...');

exception
  when others then
    DBMS_SCHEDULER.drop_job (job_name=> 'copy_csv');
    raise;
end;
/