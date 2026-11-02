extends RefCounted

const REGIONS = [
	{
		"id": "T01", 
		"name": "边境中继站", 
		"desc": "这里没有特殊效果。", 
		"short": "无特殊效果", 
		"effect": "none", 
		"notes": [], 
		"art": 0, 
		"icon": "compass"
	}, 
	{
		"id": "T02", 
		"name": "纳米增幅场", 
		"desc": "这里的1费单位战力+2。", 
		"short": "1费单位战力+2", 
		"effect": "small", 
		"notes": [], 
		"art": 1, 
		"icon": "star"
	}, 
	{
		"id": "T03", 
		"name": "孤立星门", 
		"desc": "某方在这里只有1个单位时，该单位战力翻倍。", 
		"short": "单独驻守：战力翻倍", 
		"effect": "solo", 
		"notes": [], 
		"art": 2, 
		"icon": "arrow"
	}, 
	{
		"id": "T04", 
		"name": "轨道集结港", 
		"desc": "某方在这里放满4个单位时，该方区域总战力+5。", 
		"short": "放满4个：总战力+5", 
		"effect": "full", 
		"notes": [], 
		"art": 0, 
		"icon": "cards"
	}, 
	{
		"id": "T05", 
		"name": "恒星辐射带", 
		"desc": "这里所有单位战力+1。", 
		"short": "所有单位战力+1", 
		"effect": "all", 
		"notes": [], 
		"art": 1, 
		"icon": "star"
	}, 
	{
		"id": "T06", 
		"name": "重装船坞", 
		"desc": "这里4费及以上的单位战力+3。", 
		"short": "4费及以上战力+3", 
		"effect": "large", 
		"notes": [], 
		"art": 2, 
		"icon": "emblem"
	}, 
	{
		"id": "T07", 
		"name": "离子干扰区", 
		"desc": "这里所有单位战力-1。减到0时摧毁。", 
		"short": "所有单位战力-1", 
		"effect": "weak", 
		"notes": [
			"免疫摧毁的单位仍会保留。"
		], 
		"art": 0, 
		"icon": "close"
	}, 
	{
		"id": "T20", 
		"name": "遗骸回收带", 
		"desc": "友军在这里被摧毁后，为这里战力最低的受损友军恢复2点战力。每方限2次。", 
		"short": "友军阵亡：修复友军2", 
		"effect": "salvage", 
		"notes": [
			"只恢复已损失的战力。没有受损友军时不扣次数。"
		], 
		"art": 0, 
		"icon": "settings"
	}, 
	{
		"id": "T21", 
		"name": "相位中转站", 
		"desc": "本回合移入这里的单位，回合结束时回到出发区域。", 
		"short": "移入的单位回合末返回", 
		"effect": "phase_return", 
		"notes": [
			"出发区域按本回合第一次移动前的位置计算。原区域已满或不能移动时，留在这里。"
		], 
		"art": 2, 
		"icon": "arrow"
	}, 
	{
		"id": "T22", 
		"name": "裂盾熔池", 
		"desc": "这里的友军失去护盾后，使这里战力最高的敌军战力-1。每方每回合限1次。", 
		"short": "友军失盾：最强敌军-1", 
		"effect": "shield_retort", 
		"notes": [
			"没有敌军时不扣次数。双方都可触发。"
		], 
		"art": 0, 
		"icon": "emblem"
	}, 
	{
		"id": "T23", 
		"name": "深冷备件库", 
		"desc": "第4回合结束时，为双方这里剩余次数最少的装置各补充1次。", 
		"short": "第4回合末：装置次数+1", 
		"effect": "cold_parts", 
		"notes": [
			"只选本局还未重启过的单位，并用掉它的重启机会。次数相同时，先选左侧单位。"
		], 
		"art": 1, 
		"icon": "settings"
	}, 
	{
		"id": "T24", 
		"name": "紫晶蜕变谷", 
		"desc": "友军在这里进化后，获得护盾。每方限1次。", 
		"short": "友军进化：获得护盾", 
		"effect": "molt_shield", 
		"notes": [
			"已有护盾或已经离场时不触发，也不扣次数。"
		], 
		"art": 1, 
		"icon": "star"
	}, 
	{
		"id": "T25", 
		"name": "薪火墓原", 
		"desc": "友军在这里复活后，使其他区域战力最低的友军战力+2。每方限2次。", 
		"short": "友军复活：其他区域友军+2", 
		"effect": "revival_beacon", 
		"notes": [
			"其他区域没有友军时不扣次数。"
		], 
		"art": 0, 
		"icon": "resume"
	}, 
	{
		"id": "T26", 
		"name": "脉冲风暴带", 
		"desc": "第4、5、6回合结束时，这里所有单位战力-1。", 
		"short": "第4～6回合末：全体-1", 
		"effect": "pulse_storm", 
		"notes": [
			"护盾可以抵挡。减到0时摧毁，免疫摧毁仍有效。"
		], 
		"art": 1, 
		"icon": "close"
	}, 
	{
		"id": "T27", 
		"name": "隔离检疫港", 
		"desc": "第5回合结束时，双方各将这里费用最低的1个低费单位返回手牌。", 
		"short": "第5回合末：低费单位回手", 
		"effect": "quarantine", 
		"notes": [
			"低费指原始费用不超过2。费用相同时，先选左侧单位；手牌已满则不回手。保留增减益和技能次数。"
		], 
		"art": 2, 
		"icon": "cards"
	}, 
	{
		"id": "T28", 
		"name": "引力天秤", 
		"desc": "这里每方只计算战力最高的2个单位的分数。", 
		"short": "只计最强2个单位的战力", 
		"effect": "gravity_scales", 
		"notes": [
			"其他单位仍占位置，技能照常生效。"
		], 
		"art": 2, 
		"icon": "emblem"
	}, 
	{
		"id": "T29", 
		"name": "赤砂能量井", 
		"desc": "友军在这里用战力发动技能后，下回合能量+1。每方每回合限1次，每局限2次。", 
		"short": "用战力发动技能：下回合能量+1", 
		"effect": "blood_energy", 
		"notes": [
			"只算主动支付战力。下回合额外能量最多+2；最后一回合不触发。"
		], 
		"art": 0, 
		"icon": "star"
	}
]
