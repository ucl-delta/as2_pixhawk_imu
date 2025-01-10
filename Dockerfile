FROM osrf/ros:humble-desktop

WORKDIR /root/

RUN apt-get update
RUN apt-get install apt-utils software-properties-common -y

RUN apt install git tmux tmuxinator -y
## ROS2 utils

RUN apt-get install python3-rosdep  \
                python3-pip     \
                python3-colcon-common-extensions \
                python3-colcon-mixin \
                ros-dev-tools -y

RUN apt-get install python3-flake8 \
                python3-flake8-builtins  \
                python3-flake8-comprehensions \
                python3-flake8-docstrings \
                python3-flake8-import-order \
                python3-flake8-quotes -y

RUN pip3 install pylint
RUN pip3 install flake8==4.0.1
RUN pip3 install pycodestyle==2.8
RUN pip3 install cmakelint cpplint

RUN apt-get install cppcheck lcov -y

RUN colcon mixin update default
RUN rm -rf log # remove log folder

RUN pip3 install colcon-lcov-result cpplint cmakelint
RUN pip3 install PySimpleGUI-4-foss

RUN mkdir -p /root/aerostack2_ws/src/
WORKDIR /root/aerostack2_ws/src/
RUN git clone https://github.com/aerostack2/aerostack2.git aerostack2 -b main --depth=1
RUN git clone https://github.com/aerostack2/as2_platform_pixhawk.git as2_platform_pixhawk -b main --depth=1
RUN git clone https://github.com/PX4/px4_msgs.git px4_msgs -b release/1.14 --depth=1

WORKDIR /root/aerostack2_ws
RUN rosdep update
RUN rosdep fix-permissions
RUN rosdep install --from-paths src --ignore-src -r -y

RUN . /opt/ros/$ROS_DISTRO/setup.sh \
    && colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release \
        --packages-select \
            as2_core \ 
            as2_msgs \
            as2_state_estimator \
            px4_msgs \
            as2_platform_pixhawk \
            as2_alphanumeric_viewer
            
RUN echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> ~/.bashrc
RUN echo 'export AEROSTACK2_PATH=/root/aerostack2_ws/src/aerostack2' >> ~/.bashrc
RUN echo 'source $AEROSTACK2_PATH/as2_cli/setup_env.bash' >> ~/.bashrc

WORKDIR /root/aerostack2_ws/src/
RUN git clone https://github.com/aerostack2/project_px4_vision.git project_px4_vision -b main --depth=1
WORKDIR /root/aerostack2_ws/src/project_px4_vision
COPY tmuxinator/aerostack2.yaml tmuxinator/aerostack2.yaml 

CMD ["./launch_as2.bash"]

