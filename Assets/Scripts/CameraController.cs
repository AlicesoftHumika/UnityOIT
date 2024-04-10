using UnityEngine;

public class CameraController : MonoBehaviour
{
    public Transform pivot;                      // 手动添加：被跟踪的对象：pivot——以什么为轴
    public Vector3 pivotOffset = Vector3.zero; // 与目标的偏移量
    public Transform target;                     // 像一个被选中的对象(用于检查cam和target之间的对象)
    public float distance = 10.0f;     // 距目标距离(使用变焦)
    public float minDistance = 2f;        //最小距离
    public float maxDistance = 15f;       //最大距离
    public float zoomSpeed = 1f;        //速度倍率
    public float xSpeed = 250.0f;    //x速度
    public float ySpeed = 120.0f;    //y速度
    public bool allowYTilt = true;      //允许Y轴倾斜
    public float yMinLimit = -90f;      //相机向下最大角度
    public float yMaxLimit = 90f;       //相机向上最大角度
    private float x = 0.0f;      //x变量
    private float y = 0.0f;      //y变量
    private float targetX = 0f;        //目标x
    private float targetY = 0f;        //目标y
    private float targetDistance = 0f;        //目标距离
    private float xVelocity = 1f;        //x速度
    private float yVelocity = 1f;        //y速度
    private float zoomVelocity = 1f;        //速度倍率


    void Start()
    {
        var angles = transform.eulerAngles;                          //当前的欧拉角
        targetX = x = angles.x;                                   //给x，与目标x赋值
        targetY = y = ClampAngle(angles.y, yMinLimit, yMaxLimit); //限定相机的向上，与下之间的值，返回给：y与目标y
        targetDistance = distance;                                       //初始距离数据为10；
    }


    void LateUpdate()
    {
        if (pivot) //如果存在设定的目标
        {
            float scroll = Input.GetAxis("Mouse ScrollWheel"); //获取滚轮轴
            //如果大于0，说明滚动了：那么与目标距离，就减少固定距离1。就是向前滚动，就减少值，致使越来越近
            if (scroll > 0.0f) targetDistance -= zoomSpeed;
            else if (scroll < 0.0f) targetDistance += zoomSpeed;        //距离变远             //否则
            targetDistance = Mathf.Clamp(targetDistance, minDistance, maxDistance);      //目标的距离限定在2-15之间
            if (Input.GetMouseButton(1) || Input.GetMouseButton(0) && (Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.RightControl))) //鼠标右键
            {
                targetX += Input.GetAxis("Mouse X") * xSpeed * 0.02f; //目标的x随着鼠标x移动*5
                if (allowYTilt)                                       //y轴允许倾斜
                {
                    targetY -= Input.GetAxis("Mouse Y") * ySpeed * 0.02f; //目标的y随着鼠标y移动*2.4
                    targetY = ClampAngle(targetY, yMinLimit, yMaxLimit); //限制y的移动范围在-90到90之间
                }
            }
            #region 使用了平滑插值
            x = Mathf.SmoothDampAngle(x, targetX, ref xVelocity, 0.3f);  //使用了平滑插值
            if (allowYTilt) y = Mathf.SmoothDampAngle(y, targetY, ref yVelocity, 0.3f);
            else y = targetY;
            Quaternion rotation = Quaternion.Euler(y, x, 0);
            distance = Mathf.SmoothDamp(distance, targetDistance, ref zoomVelocity, 0.5f);
            Vector3 position = rotation * new Vector3(0.0f, 0.0f, -distance) + pivot.position + pivotOffset;
            transform.rotation = rotation;
            transform.position = position;
            #endregion

            #region 不使用平滑插值
            //targetY = ClampAngle(targetY, yMinLimit, yMaxLimit);
            //Quaternion rotation1 = Quaternion.Euler(targetY, targetX, 0);
            //distance = Mathf.SmoothDamp(distance, targetDistance, ref zoomVelocity, 0f);
            //Vector3 position1 = rotation1 * new Vector3(0.0f, 0.0f, -distance) + pivot.position + pivotOffset;
            //transform.rotation = rotation1;
            //transform.position = position1; 
            #endregion
        }
    }


    /// <summary>
    /// 限定一个值，在最小和最大数之间，并返回
    /// </summary>
    /// <param name="angle"></param>
    /// <param name="min"></param>
    /// <param name="max"></param>
    /// <returns></returns>
    private float ClampAngle(float angle, float min, float max)
    {
        if (angle < -360) angle += 360;
        if (angle > 360) angle -= 360;
        return Mathf.Clamp(angle, min, max);
    }
}