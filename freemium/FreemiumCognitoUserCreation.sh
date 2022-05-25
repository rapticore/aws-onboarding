#Set the User Information before running this script
export COGNITOUSERPOOLID=us-west-2_XPwQB4QGi
export USERGROUPNAME=rapticore-freemium
export USERNAME=saquibaltaf@gmail.com
export TEMP-PASSWORD=Rapticore@freemium123
export EMAIL=saquibaltaf@gmail.com
export FIRSTNAME=Saqib 
export LASTNAME=Altaf
export PHONENO=+923345184915 // Phone number must be entered in format  +(Country Code)(MobileNo)
export USERROLE=Member

export AWS_ACCESS_KEY_ID="ASIAWCLYLRVNVILEKDWN"
export AWS_SECRET_ACCESS_KEY="hPOYD6g1L8+YMF1D9JJgvuwQLUPCohYqivqKnK4T"
export AWS_SESSION_TOKEN="IQoJb3JpZ2luX2VjEJ7//////////wEaCXVzLXdlc3QtMiJIMEYCIQC9dNVPnhCywmITON7p8AnCAAuYizBOV//PLEf3kYxB6wIhAKMBNn0Nn9DElsjwHCThpRiKIyej2Da/Dq3eqj/vtp5HKqUDCIb//////////wEQABoMNDE3NDAxMTEzOTQ3Igy3qnJ3FANQMiUFFcAq+QLXsaUmT36IBVYVa3qK7qOE5qttMTdTZBihhpTKqAeRZ+oO324iMywhJB0osB+FxB+IKRjOgIT5ZUUUfqtckvb5PPTvEmfR9sIRr3EoEXxV6kajfo8ckzmSmKXJ4GpAyseOAuCi1LBn3fD3TATY4h4zKnd7L6STNRIH/u164Khss464rqs02K6ky2RapPjvAepbpBvwgNY9HMt3b6oMbZ0dbmpfBLThn1cT9kr0SnW4+zZSeQgw0ToMGsawrKkS3kbJVL/FBFHRSNPD5fZ+sQGYUq9DOIsLAf3qbjHSrI4s+c2KoP3jlC3fyZ6hBXtN4O2B9bQe8ol8/CSKsSPIWUuykLTenFWx3KHlj6cdhAXZ3D9hgho2olipD23QoP3PJvJ3Yvm1fRc9l5BcOEAA0dSWb/McAdMYQK+vGooX3s4qI/PolFZa9xkZlPpyvfdDf9rCxpHAI638AHGsbQbEMyprTFfNA8ihtA+z/Nf5RSvaH8XYYO+nSY5T0jDG+baUBjqlAdYsIqYhZL8Rkb0iaIimZPv7n0JAFT0jfpqeYp8xwsE6SYyX2Ar9IboZNH/4bo2FnCKKTiqsIS4XCluYvPnd9udisMNXWh36f23stZ8NVCWXRQdg1XuDUqkgDu3LfP7viy0l2Wgl3cqxB8fE7P3Elux/60q/uJZP+ywO7RI70ypvcWP38htCwQQk65eNYJurZ6mid+8ZsxplCD6q2h5PAOw60k05zg=="


#Create New Group
aws cognito-idp create-group --user-pool-id us-west-2_XPwQB4QGi --group-name rapticore-freemium --description "This group consists of all users get registered for rapticore freemium"


#Create New User
aws cognito-idp admin-create-user \
    --user-pool-id $COGNITOUSERPOOLID \
    --username $EMAIL \
    --temporary-password TEMP-PASSWORD \
    --user-attributes Name=email,Value=$EMAIL Name=given_name,Value=$FIRSTNAME Name=family_name,Value=$LASTNAME Name=phone_number,Value=$PHONENO Name=custom:userRole,Value=$USERROLE Name=email_verified,Value=true Name=phone_number_verified,Value=true \
    --desired-delivery-mediums "EMAIL"
    
#Add User to Group
aws cognito-idp admin-add-user-to-group --user-pool-id $COGNITOUSERPOOLID --username $EMAIL --group-name $USERGROUPNAME