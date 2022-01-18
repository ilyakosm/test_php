/* 1 пример sql-запрос */
SELECT
    '<a name="'|| su_NK.pk_st_uch_nagr_kaf ||'"> <span>'|| 
                        apex_item.checkbox2(p_idx => 1,
                        p_value => su_NK.pk_st_uch_nagr_kaf,
                        p_attributes => 'class="chbox_UpdColl",',
                        p_checked_values => a.c001) 
    ||'</span> </a>'
    as cbox,

    case when su_NK.VID_ST = 1 then '<href="'||
            APEX_PAGE.GET_URL(
                p_page => 17, 
                p_items => 'P17_PK_ROOT', 
                p_values => su_NK.PK_ST_UCH_NAGR_KAF, 
                p_clear_cache => 17)
            ||'"> <span class="fa fa-format" aria-hidden="true"></span>'
         else '&nbsp'
        --  '<a name="'|| su_NK.pk_st_uch_nagr_kaf ||'"></a>'
            end as one_potok,

    nvl(trim(Disspr.NAME), trim(dvid.name)) AS DIS_NAME,
    su_NK.DIS,
    
    (select
        rtrim (xmlagg (xmlelement (e, trim(gr.name) || ', ') order by gs.PK_ST_UCH_NAGR_KAF).extract('//text()'),', ') --замена listagg
        from hidden_table_name gr, hidden_table_name gs
        where gr.grp = gs.grp and gs.PK_ST_UCH_NAGR_KAF = su_NK.PK_ST_UCH_NAGR_KAF) as GRPS,

    case when su_NK.UP_PR_EX = 1 then '<span class="fa fa-check" style="color: green;"></span>'
            else '__' end as UP_PR_EX,

    su_NK.VID_DIS,
    
    case when su_NK.PRP is not null then (select pr.fio_kn from hidden_table_name pr where su_NK.PRP = pr.prp)
         when su_NK.PRP is null then (select 
         rtrim (xmlagg (xmlelement (e, pr.prp || ', ') order by psu_nk.PK_ST_UCH_NAGR_KAF).extract('//text()'),', ') 
                        from hidden_table_name psu_nk, hidden_table_name pr
                        where psu_nk.PK_ST_UCH_NAGR_KAF = su_NK.PK_ST_UCH_NAGR_KAF
                                and pr.prp = psu_nk.prp) 
    end as PRP,
    
    case
        when (su_NK.PK_ST_UCH_POR_FAK is null 
                and su_NK.pk_dvid_uch_nagr is null
                and su_NK.vid_st != 1) or su_PF.f_del = 1 then 'needs_purple' 
    end as css_row_pr_delete,    

    case
        when su_NK.kol_stud != su_PF.KOL_STUD then 
        'style="background-color: #ff00004f; padding: 2px;"
        title="Количество студентов отличается от указанного в учебном поручении ('||su_PF.KOL_STUD||')"' 
    end as css_row_kol_stud,


    (select 
            'class="needs_prp" title="'|| rtrim (xmlagg (xmlelement (e, case    --замена listagg
                when te.PR_USE_TEXT_ERROR = 1 then te.text_error
                else ke.text_error
            end || ' ') order by su_NK.pk_st_uch_nagr_kaf).extract('//text()'),' ') || '"'
        from
            hidden_table_name ke,
            hidden_table_name te
        where
            ke.pk_type_error = te.pk_type_error
            and su_NK.pk_st_uch_nagr_kaf = ke.pk_st_uch_nagr_kaf
        group by su_NK.pk_st_uch_nagr_kaf) as txt_err_prp,

    su_NK.VIDP
    
FROM 
    hidden_table_name su_NK,
    hidden_table_name Disspr,
    hidden_table_name Fakspr,
    hidden_table_name su_PF,
    hidden_table_name dvid,
    apex_collections a
WHERE 
    su_NK.DIS = Disspr.DIS(+)
    and a.c001 (+)= su_NK.pk_st_uch_nagr_kaf
    and a.collection_name (+)= 'CHBOXCOLL'
    AND su_NK.FAK = Fakspr.FAK
    AND su_NK.PK_ST_UCH_POR_FAK = su_PF.PK_ST_UCH_POR_FAK(+)
    AND su_NK.PK_UCH_POR = :P9_PK_UCH_POR
    AND su_NK.KAF = :P9_KAF
    AND su_NK.PK_UCH_POR = su_PF.PK_UCH_POR(+)
    AND su_NK.KAF = su_PF.KAF(+)
    and su_NK.VID_ST != 2 --строка которая входит в поток
    and su_NK.pk_dvid_uch_nagr = dvid.pk_dvid_uch_nagr(+)
ORDER BY KURS, su_NK.ID_DIS, NVL(VID_ST,0) DESC, GRPS, SEM

/*****************************************************
******************************************************
*****************************************************/

/* 2 пример sql-запрос */
/* ПРОЦЕДУРА*/
--hidden_table_name - скрытое наименование таблицы
procedure diss_in_idx (p_id_kvart IN NUMBER) -- получание id квартала в функцию
    IS
        cursor c_info_diss (pkdis number) is -- нужная информация о диссертации
          select
                (case 
                    when d.sotr is not null 
                        then trim(s.family) || ' ' || trim(s.name) || ' ' || trim(s.patr)
                    else null
                end) as author,           -- если ненулевой, значит автор из АлтГТУ
                (select 
                    (case 
                        when hd.sotr is not null
                            then hd.sotr
                        else null
                    end) table_name
                    from hidden_table_name hd
                    where hd.pk_dissertation = pkdis
                            and hd.sotr is not null
                            and rownum = 1) --rownum = 1 чтобы вернуло 1 строку, нам не важно сколько в диссертации науч руков на данной стадии, важно что они есть из АлтГТУ
                as hd_pk_dissertation_sotr,     -- если ненулевой, значит науч рук из АлтГТУ
                d.pk_type_dissertation as typediss,
                (to_char(d.date_def, 'DD mon YYYY') || 'г. в ' || d.place_def || ' состоялась защита '
                    || case 
                            when d.pk_type_dissertation = 1 then 'докторской '
                            when d.pk_type_dissertation = 2 then 'кандидатской '
                        end 
                || 'диссертации на тему: "' || d.theme || '" по специальности ' || agg_specialties_only_shifr(d.PK_DISSERTATION, ',') --функция возвращает список специальностей
                )as prim
          from
                hidden_table_name d,
                hidden_table_name s
          where
                d.sotr = s.sotr (+)
                and d.pk_dissertation = pkdis;
    
        cursor c_head_diss (pkdis number) is    -- науч рук/консультант на основе диссертации
            select
                hd.sotr
            from
                hidden_table_name hd,
                hidden_table_name d,
                hidden_table_name s
            where
                pkdis = d.pk_dissertation
                and d.pk_dissertation = hd.pk_dissertation
                and hd.sotr = s.sotr;
    
        cursor c_pk_diss is     -- конкретная диссертация с учетом квартала
            select 
                d.pk_dissertation as pkdis,
                nvl(d.u_m,user) as user_dis,
                d.sotr as pksotr,
                nvl(d.d_m,sysdate) as date_dis,
                nvl(d.fil,0) as fil,
                (case
                    when ivp.pk_dissertation is null then 1
                    when ivp.pk_dissertation is not null then 2
                end) as check_ivp_diss,
                ivp.id_vip_pk as pk_vip
            from
                hidden_table_name ik,
                hidden_table_name d,
                hidden_table_name ivp
            where
                d.date_def between to_date('01.01.'||ik.yr,'DD.MM.YYYY') and nvl(ik.dat_end_vv,to_date('31.12.'||ik.yr,'DD.MM.YYYY'))
                and (d.d_m > ivp.d_m or d.d_m is null)
                and ik.id_idx_kvartal = p_id_kvart
                and ivp.pk_dissertation(+) = d.pk_dissertation;
    
    l_seq_idx_vip_pk number := null;    --pk idx_vip
    l_pk_prp number := null;   --id prp
    l_out varchar2(4000) := null;   --примечание
    l_pk_ierarh_sois number := null;    -- pk ierarh соискателя
    l_pk_ierarh_nauch number := null;   -- pk ierarh науч рука
    l_pk_id_pokaz_sois number := null;
    l_pk_id_pokaz_nauch number := null;
    
    function get_l_pk_prp (pksotr number) -- из id sotr получаем id prp
            return number
            is
                cursor cur is
                    select
                        p.prp
                    from
                        hidden_table_name s,
                        hidden_table_name p
                    where
                        s.sotr = pksotr
                        and s.kod1c_fl = p.kod1c_fl
                    order by nvl(p.wr,0) desc, nvl(p.pr_isp,0) desc;
            begin
                for rw in cur loop
                    return rw.prp;
                end loop;
                return null;
            end get_l_pk_prp;
    
    function get_id_idx_ierarh (pk_pokaz number) -- получаем id_idx_ierarh_pk
            return number
            is
                l_id_ierarh number := null;
            begin
                select
                    ier.id_idx_ierarh_pk
                into
                    l_id_ierarh
                from
                    hidden_table_name ier
                where
                    ier.id_idx_pokazatel = pk_pokaz;
                if l_id_ierarh is null then
                    return null;
                end if;
                return l_id_ierarh;
            end get_id_idx_ierarh;
    
    begin
        for i in c_pk_diss
        loop
            for j in c_info_diss(i.pkdis)
            loop
                if (j.author is not null or j.hd_pk_dissertation_sotr is not null) then --проверка соискатель или науч рук
                    if j.typediss = 1 then
                        --поменять цифры!
                        l_pk_ierarh_sois := get_id_idx_ierarh(887);--2439;
                        l_pk_id_pokaz_sois := 887;
                        l_pk_ierarh_nauch := get_id_idx_ierarh(885);--2435;
                        l_pk_id_pokaz_nauch := 885;
                        --DBMS_OUTPUT.PUT_LINE('Выбрана докторская диссертация');
                    elsif j.typediss = 2 then
                        --поменять цифры!
                        l_pk_ierarh_sois := get_id_idx_ierarh(886);--2437;
                        l_pk_id_pokaz_sois := 886;
                        l_pk_ierarh_nauch := get_id_idx_ierarh(884);--2433;
                        l_pk_id_pokaz_nauch := 884;
                        --DBMS_OUTPUT.PUT_LINE('Выбрана кондидатская диссертация');
                    end if;
    
                    if (l_pk_ierarh_nauch is not null and l_pk_ierarh_sois is not null) then
                        if (j.author is not null) then    -- если автор из АлтГТУ
                            --DBMS_OUTPUT.PUT_LINE('Автор из АлтГТУ');
                            l_pk_prp := get_l_pk_prp(i.pksotr);     --получение prp для сотрудника
                            l_out := j.author || ' ' || j.prim;     --фио и описание для примечания
                            if i.check_ivp_diss = 1 then
                                l_seq_idx_vip_pk := adm.get_seq_val(hidden_table_name);
                                INSERT INTO hidden_table_name 
                                    (id_vip_pk, prp, id_idx_ierarh_pk, zn, id_idx_kvartal, u_m, d_m, komment, fil, pk_dissertation, id_idx_pokazatel) 
                                VALUES
                                    (l_seq_idx_vip_pk, l_pk_prp, l_pk_ierarh_sois, 1, p_id_kvart, i.user_dis, sysdate, l_out, i.fil, i.pkdis, l_pk_id_pokaz_sois);
                                --DBMS_OUTPUT.PUT_LINE('Данные заполнены');
                            elsif (i.check_ivp_diss = 2 and i.pk_vip is not null) then
                                update hidden_table_name
                                    set prp = l_pk_prp, id_idx_ierarh_pk = l_pk_ierarh_sois, zn = 1,
                                        id_idx_kvartal = p_id_kvart, u_m = i.user_dis, d_m = sysdate,
                                        komment = l_out, fil = i.fil, pk_dissertation = i.pkdis, id_idx_pokazatel = l_pk_id_pokaz_sois
                                    where id_vip_pk = i.pk_vip;
                                --DBMS_OUTPUT.PUT_LINE('Данные обновлены');
                            end if;
                        end if; 
    
                        if (j.hd_pk_dissertation_sotr is not null) then  -- если науч рук из АлтГТУ
                            for h in c_head_diss(i.pkdis) 
                            loop
                                l_pk_prp := get_l_pk_prp(h.sotr);   --получение idprp для научного руководителя
                                l_out := j.prim;                    --описание для примечания
                                --DBMS_OUTPUT.PUT_LINE('Научный руководитель/консультант из АлтГТУ');
                                if i.check_ivp_diss = 1 then    
                                    l_seq_idx_vip_pk := adm.get_seq_val(hidden_table_name);
                                    INSERT INTO hidden_table_name 
                                        (id_vip_pk, prp, id_idx_ierarh_pk, zn, id_idx_kvartal, u_m, d_m, komment, fil, pk_dissertation, id_idx_pokazatel) 
                                    VALUES 
                                        (l_seq_idx_vip_pk, l_pk_prp, l_pk_ierarh_nauch, 1, p_id_kvart, i.user_dis, sysdate, l_out, i.fil, i.pkdis, l_pk_id_pokaz_nauch);
                                    --DBMS_OUTPUT.PUT_LINE('Данные заполнены');
                                elsif (i.check_ivp_diss = 2 and i.pk_vip is not null) then
                                    update hidden_table_name
                                        set prp = l_pk_prp, id_idx_ierarh_pk = l_pk_ierarh_nauch, zn = 1,
                                            id_idx_kvartal = p_id_kvart, u_m = i.user_dis, d_m = sysdate,
                                            komment = l_out, fil = i.fil, pk_dissertation = i.pkdis, id_idx_pokazatel = l_pk_id_pokaz_nauch
                                        where id_vip_pk = i.pk_vip;
                                    --DBMS_OUTPUT.PUT_LINE('Данные обновлены');
                                end if;
                            end loop;
                        end if;
                    end if;
                end if;
            end loop;
        end loop;
    end diss_in_idx; 