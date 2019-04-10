//
`timescale 1ms/1ms
module pingpang (rst,play1,play2,light,sel,dig,HSE);
input rst;          			//rst全局复位
input play1,play2;  			//玩家1和玩家2击球按键
input HSE;              	//50MHz外部晶振
output [7:0]sel;   			//数码管段选
output [7:0]dig; 				//数码管位选
output [15:0]light;       	//16个LED模拟乒乓球台

reg [7:0]sel;
reg [7:0]dig;
wire rst,HSE;
wire play1,play2;

reg clk;					//100Hz系统工作时钟
reg clk_1khz;			//1000Hz数码管扫描时钟
reg [15:0]light;
reg [3:0]sum1,sum2;	//玩家1和玩家2的当局得分

reg [36:0]counter;	//用于50MHz的HSE分频
reg [36:0]counter1;	//用于50MHz的HSE分频
reg [6:0]cnt1,cnt2; 	//cnt1用于0.4s计数，cnt2用于0.8s计数

reg [7:0]led_p11,led_p12,led_p21,led_p22;		//led_p11为玩家1分数个位显示译码器，led_p12为玩家1分数十位显示译码器，玩家2同理
reg [7:0]led_j1,led_j2;								//玩家赢得的局数显示译码器
reg [2:0]jushu_p1,jushu_p2;						//jushu_p1为玩家1赢得的局数，jushu_p2为玩家2赢得的局数

reg [2:0]cnt;                                //数码管扫描计数器

always@(posedge HSE or negedge rst) //分频得到100Hz clk系统工作时钟
begin
	if(!rst)
		counter<=0;
	else if(HSE)
	begin
		if(counter>249999)
			begin counter<=0; clk<=~clk;end
		else
			counter<=counter+1;
	end
end
//
always@(posedge HSE or negedge rst)//分频得到1000Hz 数码管扫描工作时钟
begin
	if(!rst)
		counter1<=0;
	else if(counter1 > 24999)
		begin counter1<=0;clk_1khz=~clk_1khz; end
	else counter1<=counter1+1;
end
//


always @ (posedge clk or negedge rst)   //0.4s溢出清零一次
if (!rst)
   cnt1<=0;
else if (clk) 
   begin 
	if(cnt1>7'b010_0111)//39
		cnt1<=0;
	else 
		cnt1<=cnt1+1'b1;
	end 
//

always @ (posedge clk or negedge rst)   //0.8s溢出清零一次
if (!rst)
   cnt2<=0;
else if (clk) 
   begin 
	if(cnt2>7'b100_1111)//79
	cnt2<=0;
	else 
	cnt2<=cnt2+1'b1;
	end 
//

parameter//状态机设置
s_0=4'b0000,//初始状态
s_1=4'b0001,//玩家1发球
s_2=4'b0010,//0.4S  1->2
s_3=4'b0011,//0.8S  1->2
s_4=4'b0100,//0.4S  1->2 判断玩家2击球       
s_5=4'b0101,//0.4S  2->1
s_6=4'b0110,//0.8S  2->1
s_7=4'b0111,//0.4S  2->1 判断玩家1击球
s_8=4'b1000,//玩家2发球
s_9=4'b1001,//玩家1积一分
s_10=4'b1010,//玩家2积一分
s_11=4'b1011,//球权移交给玩家1
s_12=4'b1100;//球权移交给玩家2


reg [3:0]stage; //状态标志位
//

always @ (posedge clk or negedge rst)
if (!rst)
   begin 
	stage<=s_0;
	sum1<=0;
	sum2<=0;
	jushu_p1<=0;
	jushu_p2<=0;
	light<=16'b0000_0000_0000_0000;
	end 
else case(stage)

s_0:begin
   light<=16'b1000_0000_0000_0001;
	if(!play1)
   stage<=s_1;
   else if (!play2)
   stage<=s_8;
   else stage<=s_0;
   end 
	
s_1:begin 
   light<=16'b0000_0000_0000_0001;
   stage<=s_2;
   end 
	
s_2:if(cnt1==7'b010_0111)	//0.4s
   light<=(light<<1);
    else if(light==16'b0000_0000_0000_1000)
	stage<=s_3;
    else stage<=s_2;
	 
s_3:if(cnt2==7'b100_1111)	//0.8s
   light<=(light<<1);
	else if (light==16'b0000_1000_0000_0000)
	stage<=s_4;
	else stage<=s_3;
	
s_4:if(cnt1==7'b010_0111)	//0.4s
   light<=(light<<1);
	else if(light<=16'b1000_0000_0000_0000)
	begin 
	stage <=s_4;
	if (light<16'b1000_0000_0000_0000&&!play2)
	stage<=s_5;
	else if (light==16'b1000_0000_0000_0000)
	stage<=s_9;
	end 
	
s_5:if(cnt1==7'b010_0111)	//0.4s
   light<=(light>>1);
	else if (light==16'b0001_0000_0000_0000)
	stage<=s_6;
	else stage=s_5;
	
s_6:if(cnt2==7'b100_0111)	//0.8s
   light<=(light>>1);
	else if(light==16'b0000_0000_0001_0000)
	stage<=s_7;
	else stage<=s_6;
	
s_7:if(cnt1==6'b010_0111)	//0.4s
   light<=(light>>1);
	else if (light>=16'b0000_0000_0000_0001)
	begin 
	stage<=s_7;
	if(light>16'b0000_0000_0000_0001&&!play1)
	stage<=s_2;
	else if (light==16'b0000_0000_0000_0001)
	stage<=s_10;
	end 
	
s_8:begin 
   light<=16'b1000_0000_0000_0000;
	stage<=s_5;
	end 
	
s_9:begin
   sum1<=sum1+1'b1;

		stage<=s_11;
	end 
	
s_10:begin 
   sum2<=sum2+1'b1;
	stage<=s_12;
	end 
		
s_11:begin 
  	if (sum1==4'b1011&sum2<4'b1001)//当前局获胜判断：一方先获得11分并且领先2分以上认为当前局获胜，否则比赛继续
		begin jushu_p1<=jushu_p1+1'b1;sum1<=4'b0000; sum2<=4'b0000;stage<=s_0;end
	else if (sum2==4'b1011&sum1<4'b1001)
		begin	jushu_p2<=jushu_p2+1'b1;sum1<=4'b0000; sum2<=4'b0000;stage<=s_0;end
	else if(sum1>4'b1011&((sum1-sum2)>1))
		begin jushu_p1<=jushu_p1+1'b1;sum1<=4'b0000; sum2<=4'b0000;stage<=s_0;end
	else if(sum2>4'b1011&((sum2-sum1))>1)
		begin jushu_p2<=jushu_p2+1'b1;sum1<=4'b0000; sum2<=4'b0000;stage<=s_0;end
	else
	begin
	if(!play1)//等待玩家1发球
		stage<=s_1;
	else
		 stage<=s_11;
	end
	end	
s_12:begin 
 	if (sum1==4'b1011&sum2<4'b1001)//当前局获胜判断：一方先获得11分并且领先2分以上认为当前局获胜，否则比赛继续
		begin jushu_p1<=jushu_p1+1'b1;sum1<=4'b0000; sum2<=4'b0000;stage<=s_0;end
	else if (sum2==4'b1011&sum1<4'b1001)
		begin	jushu_p2<=jushu_p2+1'b1;sum1<=4'b0000; sum2<=4'b0000;stage<=s_0;end
	else if(sum1>4'b1011&((sum1-sum2)>1))
		begin jushu_p1<=jushu_p1+1'b1;sum1<=4'b0000; sum2<=4'b0000;stage<=s_0;end
	else if(sum2>4'b1011&((sum2-sum1))>1)
		begin jushu_p2<=jushu_p2+1'b1;sum1<=4'b0000; sum2<=4'b0000;stage<=s_0;end
	else 
  begin
	if(!play2)//等待玩家2发球
		stage<=s_8;
	else
		 stage<=s_12;
	end
	end
endcase 
//




//数码管显示部分
always@(posedge clk_1khz or negedge rst)//1khz扫描频率
if (!rst)
	cnt<=0;
else 
	cnt<=cnt+1'b1;


always @(cnt) //数码管1~8位轮流扫描显示
case(cnt)
	3'b000:dig=8'b0111_1111;
	3'b001:dig=8'b1011_1111;
	3'b010:dig=8'b1101_1111;
	3'b011:dig=8'b1110_1111;
	3'b100:dig=8'b1111_0111;
	3'b101:dig=8'b1111_1011;
	3'b110:dig=8'b1111_1101;
	3'b111:dig=8'b1111_1110;	
endcase 
//

always@(dig)
case (dig)
8'b0111_1111:sel=led_j1;  					//数码管第一位显示玩家1获胜局数
8'b1011_1111:sel=led_j2;					//数码管第二位显示玩家2或胜局数
8'b1101_1111:sel=8'b1111_1111;			//数码管第三位不显示
8'b1110_1111:sel=led_p12;					//数码管第四位显示玩家1分数十位
8'b1111_0111:sel=led_p11;					//数码管第五位显示玩家1分数个位
8'b1111_1011:sel=8'b1111_1111;			//数码管第六位不显示
8'b1111_1101:sel=led_p22;					//数码管第七位显示玩家2分数十位
8'b1111_1110:sel=led_p21;					//数码管第八位显示玩家2分数个位
endcase


always@(posedge clk)
case (jushu_p1)
3'b000:led_j1<=8'b1100_0000;//0
3'b001:led_j1<=8'b1111_1001;//1
3'b010:led_j1<=8'b1010_0100;//2
3'b011:led_j1<=8'b1011_0000;//3
3'b100:led_j1<=8'b1001_1001;//4
endcase 

always@(posedge clk)
case (jushu_p2)
3'b000:led_j2<=8'b1100_0000;//0
3'b001:led_j2<=8'b1111_1001;//1
3'b010:led_j2<=8'b1010_0100;//2
3'b011:led_j2<=8'b1011_0000;//3
3'b100:led_j2<=8'b1001_1001;//4
endcase 
//

always@(sum1)  //玩家1分数译码
case (sum1)
4'b0000://0
begin
led_p11<=8'b1100_0000;//0
led_p12<=8'b1100_0000;//0
end 
4'b0001://1
begin
led_p11<=8'b1111_1001;//1
led_p12<=8'b1100_0000;//0
end 
4'b0010://2
begin
led_p11<=8'b1010_0100;//2
led_p12<=8'b1100_0000;//0
end 
4'b0011://3
begin
led_p11<=8'b1011_0000;//3
led_p12<=8'b1100_0000;//0
end 	
4'b0100://4
begin
led_p11<=8'b1001_1001;//4
led_p12<=8'b1100_0000;//0
end 	
4'b0101://5
begin
led_p11<=8'b1001_0010;//5
led_p12<=8'b1100_0000;//0
end 	
4'b0110://6
begin
led_p11<=8'b1000_0010;//6
led_p12<=8'b1100_0000;//0
end 	
4'b0111://7
begin
led_p11<=8'b1111_1000;//7
led_p12<=8'b1100_0000;//0
end 	
4'b1000://8
begin
led_p11<=8'b1000_0000;//8
led_p12<=8'b1100_0000;//0
end 	
4'b1001://9
begin
led_p11<=8'b1001_0000;//9
led_p12<=8'b1100_0000;//0
end
4'b1010://10
begin
led_p11<=8'b1100_0000;//0
led_p12<=8'b1111_1001;//1
end 	
4'b1011://11
begin
led_p11<=8'b1111_1001;//1
led_p12<=8'b1111_1001;//1
end 	
4'b1100://12
begin
led_p11<=8'b1010_0100;//2
led_p12<=8'b1111_1001;//1
end 
4'b1101://13
begin
led_p11<=8'b1011_0000;//3
led_p12<=8'b1111_1001;//1
end 		
4'b1110://14
begin
led_p11<=8'b1001_1001;//4
led_p12<=8'b1111_1001;//1
end 		
4'b1111://15
begin
led_p11<=8'b1001_0010;//5
led_p12<=8'b1111_1001;//1
end 		
endcase 
//

always@(sum2)//玩家2分数译码
case (sum2)
4'b0000://0
begin
led_p21<=8'b1100_0000;//0
led_p22<=8'b1100_0000;//0
end 
4'b0001://1
begin
led_p21<=8'b1111_1001;//1
led_p22<=8'b1100_0000;//0
end 
4'b0010://2
begin
led_p21<=8'b1010_0100;//2
led_p22<=8'b1100_0000;//0
end 
4'b0011://3
begin
led_p21<=8'b1011_0000;//3
led_p22<=8'b1100_0000;//0
end 	
4'b0100://4
begin
led_p21<=8'b1001_1001;//4
led_p22<=8'b1100_0000;//0
end 	
4'b0101://5
begin
led_p21<=8'b1001_0010;//5
led_p22<=8'b1100_0000;//0
end 	
4'b0110://6
begin
led_p21<=8'b1000_0010;//6
led_p22<=8'b1100_0000;//0
end 	
4'b0111://7
begin
led_p21<=8'b1111_1000;//7
led_p22<=8'b1100_0000;//0
end 	
4'b1000://8
begin
led_p21<=8'b1000_0000;//8
led_p22<=8'b1100_0000;//0
end 	
4'b1001://9
begin
led_p21<=8'b1001_0000;//9
led_p22<=8'b1100_0000;//0
end 
4'b1010://10
begin
led_p21<=8'b1100_0000;//0
led_p22<=8'b1111_1001;//1
end 	
4'b1011://11
begin
led_p21<=8'b1111_1001;//1
led_p22<=8'b1111_1001;//1
end 	
4'b1100://12
begin
led_p21<=8'b1010_0100;//2
led_p22<=8'b1111_1001;//1
end 
4'b1101://13
begin
led_p21<=8'b1011_0000;//3
led_p22<=8'b1111_1001;//1
end 		
4'b1110://14
begin
led_p21<=8'b1001_1001;//4
led_p22<=8'b1111_1001;//1
end 		
4'b1111://15
begin
led_p21<=8'b1001_0010;//5
led_p22<=8'b1111_1001;//1
end 		
endcase 

endmodule 


	
