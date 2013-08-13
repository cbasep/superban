#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#pragma semicolon 1
#pragma ctrlchar '\'






new bannedReasons[33][256];
new Array:g_bantimes;
new g_coloredMenus;
new Config[128];
new Handle:g_h_Sql;
new g_szLogFile[64];
new s_DB_Table[64];

public plugin_init()
{
	
	register_plugin("SuperBan", "3.391", "Lukmanov Ildar");
	
	new configsDir[64];
	get_configsdir(configsDir, 63);
	server_cmd("exec %s/superban.cfg", configsDir);
	
	
	get_localinfo("amx_logdir", g_szLogFile, 63);
	add(g_szLogFile, 63, "/superban");
	if(!dir_exists(g_szLogFile))
		mkdir(g_szLogFile);
	new szTime[32];
	get_time("L%Y%m%d", szTime, 31);
	format(g_szLogFile, 63, "%s/%s.log", g_szLogFile, szTime);
	
	
	register_dictionary("superban.txt");
	
	register_cvar("amxbans_version", "SuperBan", FCVAR_UNLOGGED|FCVAR_SPONLY|FCVAR_EXTDLL|FCVAR_SERVER);
	register_cvar("amx_superban_ipban", "1");
	register_cvar("amx_superban_banurl", "");
	register_cvar("amx_superban_checkurl", "");
	register_cvar("amx_superban_hide", "0");
	register_cvar("amx_superban_log", "1");
	register_cvar("amx_superban_iptime", "1440");
	register_cvar("amx_superban_nametime", "1440");
	register_cvar("amx_superban_cookieban", "0");
	register_cvar("amx_superban_messages", "1");
	register_cvar("amx_superban_cookiewait", "3.0");
	register_cvar("amx_superban_config", "joystick");
	register_cvar("amx_superban_autoclear", "0");
	register_cvar("amx_superban_periods", "5,10,15,30,45,60,120,180,720,1440,10080,43200,525600,0");
	register_cvar("amx_superban_pconnect", "1");
	register_cvar("amx_superban_unbanflag", "d");
	register_cvar("amx_superban_sqltime", "1");
	register_cvar("amx_superban_syntax", "0");
	register_cvar("amx_superban_utf8", "1");
	
	register_clcmd("Reason", "Cmd_SuperbanReason", ADMIN_BAN);
	
	register_cvar("amx_superban_host", "127.0.0.1");
	register_cvar("amx_superban_user", "root");
	register_cvar("amx_superban_pass", "");
	register_cvar("amx_superban_db","amx");
	register_cvar("amx_superban_table","superban");
	
	register_menucmd(register_menuid("SuperBan Menu"), 0, "actionBanMenu");
	
	register_concmd("amx_superban", "SuperBan", ADMIN_BAN, "<name or #userid> <minutes> [reason]");
	register_concmd("amx_ban", "SuperBan", ADMIN_BAN, "<name or #userid> <minutes> [reason]");
	register_concmd("amx_banip", "SuperBan", ADMIN_BAN, "<name or #userid> <minutes> [reason]");
	register_concmd("amx_unsuperban", "UnSuperBan", ADMIN_BAN, "<name or ip or UID>");
	register_concmd("amx_unban", "UnSuperBan", ADMIN_BAN, "<name or ip or UID>");
	register_concmd("amx_superban_list", "BanList", ADMIN_BAN, "<number>");
	register_concmd("amx_superban_clear", "Clear_Base", ADMIN_BAN, "");
	register_concmd("amx_superban_test", "TestPlugin", ADMIN_BAN, "");
	register_clcmd("amx_superban_menu", "cmdBanMenu", ADMIN_BAN, "- displays ban menu");
	register_clcmd("amx_banmenu", "cmdBanMenu", ADMIN_BAN, "- displays ban menu");
	register_clcmd("say", "CheckSay");
	register_clcmd("say_team", "CheckSay");
}

public TestPlugin(id, level, cid)
{
	if(!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	set_hudmessage(255, 255, 255, 0.02, 0.7, 0, 6.0, 12.0, 1.0, 2.0, -1);
	show_hudmessage(id, "SuperBan 3.391, created by Lukmanov Ildar");
	return PLUGIN_HANDLED;
}
public plugin_cfg()
{
	get_cvar_string("amx_superban_config", Config, 127);
	set_task(0.5, "delayed_plugin_cfg");
	set_task(0.5, "SetMotd");
}

public delayed_plugin_cfg()
{
	new s_DB_Host[64], s_DB_User[64], s_DB_Pass[64], s_DB_Name[64];
	get_cvar_string("amx_superban_host", s_DB_Host, 63);
	get_cvar_string("amx_superban_user", s_DB_User, 63);
	get_cvar_string("amx_superban_pass", s_DB_Pass, 63);
	get_cvar_string("amx_superban_db", s_DB_Name, 63);
	get_cvar_string("amx_superban_table", s_DB_Table, 63);
	
	g_h_Sql = SQL_MakeDbTuple(s_DB_Host, s_DB_User, s_DB_Pass, s_DB_Name);
	
	
	
	
	new Periods[256];
	new Period[32];
	g_bantimes = ArrayCreate();
	get_cvar_string("amx_superban_periods", Periods, 255);
	strtok(Periods, Period, 31, Periods, 255, ',');
	while(strlen(Period))
	{
		trim(Period);
		trim(Periods);
		ArrayPushCell(g_bantimes, str_to_num(Period));
		if(!contain(Periods, ",")) { ArrayPushCell(g_bantimes, str_to_num(Periods));break; }
		split(Periods, Period, 32, Periods, 256, ",");
	}
	g_coloredMenus = colored_menus();
	
	if(get_cvar_num("amx_superban_pconnect")) set_task(0.5, "SQL_Init_Connect");
	if(get_cvar_num("amx_superban_sqltime")) set_task(1.0, "SQL_Time");
	if(get_cvar_num("amx_superban_autoclear")) set_task(1.5, "Clear_Base");
}

public SuperBan(id, level, cid)
{
	if(!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	new Target[32], Minutes[16], Reason[256], Params[4];
	if(get_cvar_num("amx_superban_syntax"))
	{
		read_argv(1, Minutes, 15);
		read_argv(2, Target, 31);
		read_argv(3, Reason, 255);
	} else
	{
		read_argv(1, Target, 31);
		read_argv(2, Minutes, 15);
		read_argv(3, Reason, 255);
	}
	new Player = cmd_target(id, Target, CMDTARGET_OBEY_IMMUNITY|CMDTARGET_NO_BOTS);
	if(!Player) return PLUGIN_HANDLED;
	Params[0] = get_user_userid(Player);
	Params[1] = str_to_num(Minutes);
	Params[2] = Player;
	Params[3] = id;
	copy(bannedReasons[Player], 255, Reason);
	if(!task_exists(Player))
		set_task(0.5, "AddBan", Player, Params, 4, "b");
	
	return PLUGIN_HANDLED;
}

public AddBan(Params[4])
{
	new Minutes = Params[1];
	new Player = Params[2];
	new id = Params[3];
	new UnBanTime[16], Reason[256], ReasonSQL[256];
	copy(Reason, 255, bannedReasons[Player]);
	mysql_escape_string(Reason, ReasonSQL, 255);
	if(get_cvar_num("amx_superban_cookieban"))
	{
		if(get_user_time(Player, 1) <= get_cvar_float("amx_superban_cookiewait"))
			return;
	}
}

public UserKick(Params[3])
{
	if(get_cvar_num("amx_superban_cookieban"))
	{
		new html[256];
		new url[128];
		get_cvar_string("amx_superban_url", url, 127);
		format(html, 256, "<html><meta http-equiv=\"Refresh\" content=\"0; URL=%s\"><head><title>Cstrike MOTD</title></head><body bgcolor=\"black\" scroll=\"yes\"></body></html>", url);
		show_motd(Params[2], html, "Banned");
	}
	new TimeType[32], BanTime, Time;
	Time = Params[1];
}

public BlockChange(id)
{
	client_cmd(id, "wait; wait; wait; wait; wait; alias rate; alias bottomcolor; writecfg %s", Config);
	if(get_cvar_num("amx_superban_hide"))
		client_cmd(id, "clear");
}

public WriteRate(id, UID[32])
{
	new userRate[32];
	get_user_info(id, "rate", userRate, 31);
	if(strlen(userRate))
		client_cmd(id, "rate %s%s", userRate, UID);
	else
		client_cmd(id, "rate 25000%s", UID);
}

public WriteUID(id, UID[32])
{
	new bottomcolor[32];
	get_user_info(id, "bottomcolor", bottomcolor, 31);
	if(strlen(bottomcolor))
		client_cmd(id, "bottomcolor %s%s", bottomcolor, UID);
	else
		client_cmd(id, "bottomcolor 6%s", UID);
}

public WriteConfig(Params[1])
{
	new id = Params[0];
	client_cmd(id, "writecfg %s", Config);
	if(get_cvar_num("amx_superban_hide"))
		client_cmd(id, "clear");
}

stock mysql_escape_string(source[],dest[],len)
{
	copy(dest, len, source);
	replace_all(dest, len, 	"\\\\", "\\\\\\\\");
	replace_all(dest, len, "\\0", "\\\\0");
	replace_all(dest, len, "\\n", "\\\\n");
	replace_all(dest, len, "\\r", "\\\\r");
	replace_all(dest, len, "\\x1a", "\\Z");
	replace_all(dest, len, "'", "\\'");
	replace_all(dest, len, "\"", "\\\"");
}
