import json,os,pathlib,subprocess,time,urllib.request,urllib.error,hashlib,tempfile
runtime=pathlib.Path('D:/BOC-Runtime')
project=pathlib.Path(__file__).resolve().parents[2]
name='boc_mall_test_'+str(os.getpid())
env=os.environ.copy();env['PGPASSWORD']=(runtime/'db-password.txt').read_text()
dbargs=['-h','127.0.0.1','-p','55432','-U','boc']
def pg(program,*args):
    return subprocess.check_output([str(runtime/'pgsql/bin'/program),*dbargs,*args],env=env,text=True,encoding='utf-8').strip()
def sql(text):return pg('psql.exe','-d',name,'-At','-c',text)
def api(path,data=None,token=None,method=None,expect=200):
    headers={'Content-Type':'application/json'}
    if token:headers['Authorization']='Bearer '+token
    request=urllib.request.Request('http://127.0.0.1:8091'+path,json.dumps(data).encode() if data is not None else None,headers,method=method)
    try:r=urllib.request.urlopen(request,timeout=20)
    except urllib.error.HTTPError as e:r=e
    body=r.read().decode('utf-8')
    try:result=json.loads(body)
    except json.JSONDecodeError:result={'error':body}
    assert r.status==expect,(path,r.status,result)
    return result
def login(user):return api('/api/login',{'username':user,'password':'test123' if user!='admin' else 'admin'})['token']
pg('createdb.exe',name)
server=None
log=tempfile.TemporaryFile(mode='w+',encoding='utf-8')
try:
    serverenv=env.copy();serverenv.update(DB_NAME=name,DB_HOST='127.0.0.1',DB_PORT='55432',DB_USERNAME='boc',DB_PASSWORD=env['PGPASSWORD'],PORT='8091',HOST='127.0.0.1')
    server=subprocess.Popen([str(runtime/'flutter/bin/cache/dart-sdk/bin/dart.exe'),'run','bin/server.dart'],cwd=project/'backend',env=serverenv,stdout=log,stderr=log)
    for _ in range(40):
        try:api('/api/test');break
        except Exception:time.sleep(.5)
    else:
        log.flush();log.seek(0)
        raise AssertionError('Test server startup failed: '+log.read())
    password=hashlib.sha256(b'test123').hexdigest()
    sql("INSERT INTO stores(code,name) VALUES('S002','Second store'); INSERT INTO raw_material_categories(code,name) VALUES('TEST_CAT','Test category'); INSERT INTO raw_materials(code,name_cn,specification,category_code) VALUES('TEST_A','Product A','bag','TEST_CAT'),('TEST_B','Product B','box','TEST_CAT'); INSERT INTO users(username,password,role,store_code) VALUES ('mall_a','"+password+"','USER','S001'),('mall_b','"+password+"','USER','S002'),('mall_none','"+password+"','USER',NULL)")
    admin,a,b,none=map(login,['admin','mall_a','mall_b','mall_none'])
    api('/api/mall/products',expect=401)
    api('/api/mall/products',token=none,expect=403)
    api('/api/mall/products',token=a,expect=403)
    api('/api/mall/orders',token=a,expect=403)
    permission={'role':'USER','storeCode':'S001','uiLanguage':'ZH','allowedCategoryCodes':[],'mallEnabled':True}
    api('/api/users/mall_a',permission,method='PUT',expect=401)
    api('/api/users/mall_a',permission,token=a,method='PUT',expect=403)
    api('/api/users/mall_a',permission,token=admin,method='PUT')
    api('/api/users/mall_b',{**permission,'storeCode':'S002'},token=admin,method='PUT')
    assert len(api('/api/mall/products',token=a)['products'])==2
    assert api('/api/login',{'username':'mall_a','password':'test123'})['mallEnabled'] is True
    api('/api/users/mall_a',{**permission,'mallEnabled':False},token=admin,method='PUT')
    api('/api/mall/products',token=a,expect=403)
    api('/api/users/mall_a',permission,token=admin,method='PUT')
    sql("UPDATE raw_materials SET name_en='English A' WHERE code='TEST_A'")
    api('/api/mall/products/TEST_A',{'outOfStock':True},token=admin,method='PUT',expect=404)
    cart={'submissionKey':'main','storeCode':'S002','actorUsername':'admin','items':[{'code':'TEST_A','quantity':2.5},{'code':'TEST_B','quantity':3}]}
    order=api('/api/mall/orders',cart,token=a)['id']
    assert api('/api/mall/orders',cart,token=a)['id']==order
    assert sql('SELECT count(*) FROM mall_orders')=='1'
    assert sql('SELECT count(*) FROM todo_tasks WHERE mall_order_id IS NOT NULL')=='1'
    owned=api('/api/mall/orders',token=a)['orders'][0]
    assert owned['storeCode']=='S001'
    assert owned['items'][0]['nameEN']=='English A'
    assert api('/api/mall/orders',token=b)['orders']==[]
    assert len(api('/api/mall/orders',token=admin)['orders'])==1
    item=owned['items'][0]['id'];other=owned['items'][1]['id']
    api(f'/api/mall/orders/{order}/items/{item}',{'purchased':True,'outOfStock':False},token=a,method='PUT',expect=403)
    api(f'/api/mall/orders/{order}/items/{item}',{'purchased':True,'outOfStock':True},token=admin,method='PUT',expect=400)
    api(f'/api/mall/orders/{order}/items/{item}',{'purchased':False,'outOfStock':True},token=admin,method='PUT')
    assert sql('SELECT status FROM todo_tasks WHERE mall_order_id='+str(order))=='有问题'
    for ident in [item,other]:api(f'/api/mall/orders/{order}/items/{ident}',{'purchased':True,'outOfStock':False},token=admin,method='PUT')
    assert sql('SELECT status FROM todo_tasks WHERE mall_order_id='+str(order))=='已做完'
    assert api('/api/mall/orders',token=a)['orders'][0]['status']=='已采购完成'
    api(f'/api/mall/orders/{order}/items/{item}',{'purchased':False,'outOfStock':False},token=admin,method='PUT')
    assert sql('SELECT status FROM todo_tasks WHERE mall_order_id='+str(order))=='未做完'
    api('/api/mall/orders',{**cart,'submissionKey':'invalid','items':[{'code':'TEST_A','quantity':1},{'code':'MISSING','quantity':1}]},token=a,expect=400)
    assert sql('SELECT count(*) FROM mall_orders')=='1'
    assert sql('SELECT count(*) FROM todo_tasks WHERE mall_order_id IS NOT NULL')=='1'
    for q in [0,-1,.001]:api('/api/mall/orders',{'submissionKey':'bad','items':[{'code':'TEST_A','quantity':q}]},token=a,expect=400)
    sql("UPDATE raw_materials SET name_cn='Renamed',name_en='Changed English' WHERE code='TEST_A'")
    assert api('/api/mall/orders',token=a)['orders'][0]['items'][0]['name']=='Product A'
    assert api('/api/mall/orders',token=a)['orders'][0]['items'][0]['nameEN']=='English A'
    task=sql('SELECT id FROM todo_tasks WHERE mall_order_id='+str(order))
    api('/api/todo-tasks/'+task,{'actorUsername':'admin'},method='PUT',expect=409)
    api('/api/todo-tasks/'+task+'?username=admin',method='DELETE',expect=409)
    # Persist rich notes, location links and store visibility through real APIs.
    api('/api/raw-material-locations',{'code':'LOC_TEST','name':'Cold storage','note':''},token=admin)
    rich=json.dumps([{'insert':'Keep refrigerated','attributes':{'bold':True}},{'insert':'\n'}])
    update={'nameCN':'Renamed','nameEN':'Changed English','locationCode':'LOC_TEST','notesRich':rich,'visibleStoreCodes':['S001']}
    api('/api/raw-materials/TEST_A',update,token=admin,method='PUT')
    raw=next(x for x in api('/api/raw-materials',token=admin)['materials'] if x['code']=='TEST_A')
    assert raw['locationCode']=='LOC_TEST' and raw['locationName']=='Cold storage'
    assert json.loads(raw['notesRich'])==json.loads(rich) and raw['hiddenStoreCodes']==['S002']
    assert 'TEST_A' not in [x['code'] for x in api('/api/raw-materials',token=b)['materials']]
    assert 'TEST_A' not in [x['code'] for x in api('/api/mall/products',token=b)['products']]
    api('/api/mall/orders',{'submissionKey':'hidden','items':[{'code':'TEST_A','quantity':1}]},token=b,expect=403)
    api('/api/stock-orders',{'orderDate':'2026-10-07','storeCode':'S002','details':[{'code':'TEST_A','orderQuantity':1}]},token=b,expect=403)
    api('/api/raw-materials/TEST_A',{**update,'visibleStoreCodes':['MISSING']},token=admin,method='PUT',expect=400)
    sql("INSERT INTO stores(code,name) VALUES('S003','New store')")
    api('/api/users/mall_b',{**permission,'storeCode':'S003'},token=admin,method='PUT')
    assert 'TEST_A' in [x['code'] for x in api('/api/mall/products',token=b)['products']]
    api('/api/raw-materials',{'code':'TEST_NEW','nameCN':'New','locationCode':'LOC_TEST'},token=admin)
    raw=next(x for x in api('/api/raw-materials',token=admin)['materials'] if x['code']=='TEST_NEW')
    assert raw['locationName']=='Cold storage' and raw['hiddenStoreCodes']==[]
    print('PASS: notes/location database persistence, store filtering, stale submission rejection, new-store defaults')
    print('PASS: authentication, store binding, owner isolation, admin permissions, quantities, atomic rollback, idempotency, historical snapshots, procurement/out-of-stock/task transitions, task protection')
finally:
    if server:
        subprocess.run(['taskkill','/PID',str(server.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        server.wait(timeout=10)
    log.close()
    pg('dropdb.exe','--force',name)

